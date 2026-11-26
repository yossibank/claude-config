import java.util.ArrayList;
import java.util.List;
import java.util.regex.Pattern;

import org.jetbrains.kotlin.com.intellij.psi.PsiElement;
import org.jetbrains.kotlin.psi.KtBlockExpression;
import org.jetbrains.kotlin.psi.KtCallExpression;
import org.jetbrains.kotlin.psi.KtDestructuringDeclaration;
import org.jetbrains.kotlin.psi.KtExpression;
import org.jetbrains.kotlin.psi.KtForExpression;
import org.jetbrains.kotlin.psi.KtIfExpression;
import org.jetbrains.kotlin.psi.KtNamedFunction;
import org.jetbrains.kotlin.psi.KtProperty;
import org.jetbrains.kotlin.psi.KtWhenExpression;

/** K9。Composable の本体の段の順。 */
final class LayoutComposable {
    static final String[] LABELS = {"", "持つ val", "派生の val", "効果", "組み立て"};
    static final int HELD = 1;
    static final int DERIVED = 2;
    static final int EFFECT = 3;
    static final int VIEW = 4;

    /** Local・モデル・remember の値。 */
    static final Pattern HELD_VALUE = Pattern.compile(
        "^(?:Local\\w*\\.current\\b|remember\\w*\\b|viewModel\\b|hiltViewModel\\b|produceState\\b)|\\.collectAs\\w*State\\w*\\b"
    );

    /** 持つ値か派生の値か、決めきれない物。モデルの中身を読む値と、動きの値。 */
    static final Pattern UNSURE_VALUE = Pattern.compile(
        "^(?:animate\\w*AsState|updateTransition)\\b|\\.(?:state|input|output)\\b"
    );

    private LayoutComposable() {}

    static List<LayoutFinding> findings(LayoutSource source) {
        List<LayoutFinding> findings = new ArrayList<>();
        walk(source, source.file, findings);
        return findings;
    }

    static void walk(LayoutSource source, PsiElement element, List<LayoutFinding> findings) {
        if (element instanceof KtNamedFunction function && LayoutDecls.isComposable(function)
            && !LayoutDecls.isPreview(function) && function.getBodyExpression() instanceof KtBlockExpression body) {
            findings.addAll(check(source, body));
        }

        for (PsiElement child = element.getFirstChild(); child != null; child = child.getNextSibling()) {
            walk(source, child, findings);
        }
    }

    static List<LayoutFinding> check(LayoutSource source, KtBlockExpression body) {
        List<LayoutFinding> findings = new ArrayList<>();
        int highest = 0;

        for (KtExpression statement : body.getStatements()) {
            int tier = tier(statement);

            if (tier == 0) {
                continue;
            }

            if (tier < highest) {
                String message = "K9: Composable の本体は、持つ val・派生の val・効果・組み立ての順に並べる。「"
                    + LABELS[tier] + "」は「" + LABELS[highest] + "」より前に置く";
                findings.add(source.finding(statement, message));
            } else {
                highest = tier;
            }
        }

        return findings;
    }

    /** 文の段。決めきれない文は 0。 */
    static int tier(KtExpression statement) {
        if (statement instanceof KtProperty property) {
            KtExpression value = property.hasDelegate() ? property.getDelegateExpression() : property.getInitializer();
            return value == null ? 0 : valueTier(value.getText().strip());
        }

        if (statement instanceof KtDestructuringDeclaration declaration) {
            KtExpression value = declaration.getInitializer();
            return value == null ? 0 : valueTier(value.getText().strip());
        }

        if (statement instanceof KtCallExpression call) {
            if (LayoutStatements.isEffect(call)) {
                return EFFECT;
            }

            String name = LayoutDecls.calleeName(call);
            return !name.isEmpty() && Character.isUpperCase(name.charAt(0)) ? VIEW : 0;
        }

        boolean isControl = statement instanceof KtIfExpression
            || statement instanceof KtWhenExpression
            || statement instanceof KtForExpression;
        boolean hasExit = statement.getText().contains("return") || statement.getText().contains("Effect");

        return isControl && !hasExit ? VIEW : 0;
    }

    static int valueTier(String text) {
        if (HELD_VALUE.matcher(text).find()) {
            return HELD;
        }

        return UNSURE_VALUE.matcher(text).find() ? 0 : DERIVED;
    }
}
