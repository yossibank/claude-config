import java.util.ArrayList;
import java.util.List;

import org.jetbrains.kotlin.com.intellij.psi.PsiElement;
import org.jetbrains.kotlin.psi.KtAnonymousInitializer;
import org.jetbrains.kotlin.psi.KtBlockExpression;
import org.jetbrains.kotlin.psi.KtClassOrObject;
import org.jetbrains.kotlin.psi.KtDeclaration;
import org.jetbrains.kotlin.psi.KtExpression;
import org.jetbrains.kotlin.psi.KtNamedFunction;
import org.jetbrains.kotlin.psi.KtProperty;
import org.jetbrains.kotlin.psi.KtPropertyAccessor;
import org.jetbrains.kotlin.psi.KtReturnExpression;
import org.jetbrains.kotlin.psi.KtSecondaryConstructor;
import org.jetbrains.kotlin.psi.KtWhenEntry;
import org.jetbrains.kotlin.psi.KtWhenExpression;

/** K8。関数・init・getter の長さ。 */
final class LayoutLengths {
    static final int MAX_LINES = 60;

    private LayoutLengths() {}

    static List<LayoutFinding> findings(LayoutSource source) {
        List<LayoutFinding> findings = new ArrayList<>();
        visit(source, source.file.getDeclarations(), findings);
        return findings;
    }

    static void visit(LayoutSource source, List<KtDeclaration> declarations, List<LayoutFinding> findings) {
        for (KtDeclaration declaration : declarations) {
            if (declaration instanceof KtNamedFunction function && function.hasBody()
                && !isTable(source, function.getBodyExpression())) {
                measure(source, function, findings);
            } else if (declaration instanceof KtAnonymousInitializer || declaration instanceof KtSecondaryConstructor) {
                measure(source, declaration, findings);
            } else if (declaration instanceof KtProperty property) {
                for (KtPropertyAccessor accessor : property.getAccessors()) {
                    if (accessor.hasBody() && !isTable(source, accessor.getBodyExpression())) {
                        measure(source, accessor, findings);
                    }
                }
            } else if (declaration instanceof KtClassOrObject type) {
                visit(source, type.getDeclarations(), findings);
            }
        }
    }

    static void measure(LayoutSource source, PsiElement element, List<LayoutFinding> findings) {
        if (source.lineCount(element) > MAX_LINES) {
            findings.add(source.finding(element, "K8: 1 つの関数は " + MAX_LINES + " 行までにする"));
        }
    }

    /** 関数と getter の本体が、全部の分岐が 1 行の when だけでできた表か。 */
    static boolean isTable(LayoutSource source, KtExpression body) {
        if (body instanceof KtBlockExpression block) {
            body = block.getStatements().size() == 1 ? block.getStatements().get(0) : null;
        }

        if (body instanceof KtReturnExpression exit) {
            body = exit.getReturnedExpression();
        }

        if (!(body instanceof KtWhenExpression when) || when.getEntries().isEmpty()) {
            return false;
        }

        for (KtWhenEntry entry : when.getEntries()) {
            if (source.isMultiline(entry)) {
                return false;
            }
        }

        return true;
    }
}
