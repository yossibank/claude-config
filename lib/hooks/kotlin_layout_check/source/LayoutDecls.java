import java.util.Set;
import java.util.function.Predicate;

import org.jetbrains.kotlin.com.intellij.psi.PsiElement;
import org.jetbrains.kotlin.lexer.KtTokens;
import org.jetbrains.kotlin.name.Name;
import org.jetbrains.kotlin.psi.KtAnnotated;
import org.jetbrains.kotlin.psi.KtAnnotationEntry;
import org.jetbrains.kotlin.psi.KtAnonymousInitializer;
import org.jetbrains.kotlin.psi.KtCallExpression;
import org.jetbrains.kotlin.psi.KtClass;
import org.jetbrains.kotlin.psi.KtClassBody;
import org.jetbrains.kotlin.psi.KtDeclaration;
import org.jetbrains.kotlin.psi.KtExpression;
import org.jetbrains.kotlin.psi.KtModifierListOwner;
import org.jetbrains.kotlin.psi.KtNamedFunction;
import org.jetbrains.kotlin.psi.KtProperty;
import org.jetbrains.kotlin.psi.KtPropertyAccessor;

/** 宣言の見分け方。アクセス・注釈・保存プロパティ・まとまり。 */
final class LayoutDecls {
    static final int PUBLIC = 1;
    static final int INTERNAL = 2;
    static final int PRIVATE = 3;

    static final Set<String> COMPUTED_DELEGATES = Set.of("lazy", "derivedStateOf");

    private LayoutDecls() {}

    static int access(KtModifierListOwner owner) {
        if (owner.hasModifier(KtTokens.PRIVATE_KEYWORD)) {
            return PRIVATE;
        }

        if (owner.hasModifier(KtTokens.INTERNAL_KEYWORD) || owner.hasModifier(KtTokens.PROTECTED_KEYWORD)) {
            return INTERNAL;
        }

        return PUBLIC;
    }

    static boolean isPrivate(KtModifierListOwner owner) {
        return access(owner) == PRIVATE;
    }

    static boolean annotated(KtAnnotated owner, Predicate<String> test) {
        for (KtAnnotationEntry entry : owner.getAnnotationEntries()) {
            Name name = entry.getShortName();

            if (name != null && test.test(name.asString())) {
                return true;
            }
        }

        return false;
    }

    static boolean isComposable(KtNamedFunction function) {
        return annotated(function, "Composable"::equals);
    }

    static boolean isPreview(KtNamedFunction function) {
        return annotated(function, name -> name.startsWith("Preview") || name.endsWith("Preview"));
    }

    /** 委譲の呼び出しの名前。`by remember { }` なら remember。 */
    static String delegate(KtProperty property) {
        KtExpression expression = property.getDelegateExpression();

        if (expression == null) {
            return "";
        }

        return calleeName(expression.getText());
    }

    static String calleeName(String text) {
        int cut = text.length();

        for (char mark : new char[] {'(', '{', '<', ' ', '\n'}) {
            int index = text.indexOf(mark);

            if (index >= 0) {
                cut = Math.min(cut, index);
            }
        }

        String head = text.substring(0, cut);
        return head.substring(head.lastIndexOf('.') + 1);
    }

    static String calleeName(KtCallExpression call) {
        return call.getCalleeExpression() == null ? "" : calleeName(call.getCalleeExpression().getText());
    }

    static boolean hasGetter(KtProperty property) {
        KtPropertyAccessor getter = property.getGetter();
        return getter != null && getter.hasBody();
    }

    static boolean isComputed(KtProperty property) {
        return hasGetter(property) || COMPUTED_DELEGATES.contains(delegate(property));
    }

    static boolean isAbstract(KtProperty property) {
        if (property.hasModifier(KtTokens.ABSTRACT_KEYWORD)) {
            return true;
        }

        PsiElement body = property.getParent();
        return body instanceof KtClassBody && body.getParent() instanceof KtClass owner && owner.isInterface();
    }

    static boolean isStored(KtDeclaration declaration) {
        return declaration instanceof KtProperty property
            && property.getReceiverTypeReference() == null
            && !isComputed(property)
            && !isAbstract(property);
    }

    /** 保存プロパティのまとまり。アクセス・val と var・委譲・setter のアクセス・const が同じ物。 */
    static String group(KtDeclaration declaration) {
        if (!(declaration instanceof KtProperty property) || !isStored(property)) {
            return null;
        }

        KtPropertyAccessor setter = property.getSetter();
        int setterAccess = setter == null ? 0 : access(setter);

        return access(property)
            + "|" + (property.isVar() ? "var" : "val")
            + "|" + delegate(property)
            + "|" + setterAccess
            + "|" + property.hasModifier(KtTokens.CONST_KEYWORD)
            + "|" + property.hasModifier(KtTokens.LATEINIT_KEYWORD);
    }

    /** 動かすと、値を作る順が変わる宣言。init と、初めの値か委譲を持つプロパティ。 */
    static boolean isOrderSensitive(KtDeclaration declaration) {
        if (declaration instanceof KtAnonymousInitializer) {
            return true;
        }

        if (!(declaration instanceof KtProperty property) || property.hasModifier(KtTokens.CONST_KEYWORD)) {
            return false;
        }

        if (isComputed(property)) {
            return false;
        }

        return property.getInitializer() != null || property.hasDelegate();
    }
}
