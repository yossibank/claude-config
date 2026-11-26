import java.util.ArrayList;
import java.util.List;

import org.jetbrains.kotlin.lexer.KtTokens;
import org.jetbrains.kotlin.psi.KtClassOrObject;
import org.jetbrains.kotlin.psi.KtDeclaration;
import org.jetbrains.kotlin.psi.KtNamedFunction;
import org.jetbrains.kotlin.psi.KtProperty;
import org.jetbrains.kotlin.psi.KtTypeAlias;

/** K1・K2。ファイルの区画の順と、拡張だけのファイルのアクセスの順。 */
final class LayoutSections {
    static final String[] LABELS = {
        "公開の const",
        "ファイルの名前の型",
        "ほかの公開の型",
        "公開と internal の値・拡張・関数",
        "private の型・拡張・関数",
        "private の値",
        "@Preview",
    };

    private LayoutSections() {}

    static List<LayoutFinding> findings(LayoutSource source) {
        List<LayoutFinding> findings = new ArrayList<>();

        if (source.file.isScript()) {
            return findings;
        }

        List<KtDeclaration> declarations = source.file.getDeclarations();
        int highest = -1;

        for (KtDeclaration declaration : declarations) {
            int rank = rank(declaration, source.stem);

            if (rank < 0) {
                continue;
            }

            if (rank < highest) {
                String message = "K1: ファイルの区画の順が違う。「" + LABELS[rank] + "」は「" + LABELS[highest] + "」より前に置く";
                findings.add(source.finding(declaration, message));
            } else {
                highest = rank;
            }
        }

        if (isExtensionsOnly(declarations)) {
            findings.addAll(accessOrder(source, declarations));
        }

        return findings;
    }

    /** 区画の番号。区画に当たらない宣言は -1。 */
    static int rank(KtDeclaration declaration, String stem) {
        boolean isPrivate = LayoutDecls.isPrivate(declaration);

        if (declaration instanceof KtNamedFunction function) {
            if (LayoutDecls.isPreview(function)) {
                return 6;
            }

            return isPrivate ? 4 : 3;
        }

        if (declaration instanceof KtProperty property) {
            if (property.hasModifier(KtTokens.CONST_KEYWORD) && !isPrivate) {
                return 0;
            }

            if (property.getReceiverTypeReference() != null) {
                return isPrivate ? 4 : 3;
            }

            return isPrivate ? 5 : 3;
        }

        if (declaration instanceof KtClassOrObject type) {
            if (stem.equals(type.getName())) {
                return 1;
            }

            return isPrivate ? 4 : 2;
        }

        if (declaration instanceof KtTypeAlias) {
            return isPrivate ? 4 : 2;
        }

        return -1;
    }

    static boolean isExtensionsOnly(List<KtDeclaration> declarations) {
        boolean hasExtension = false;

        for (KtDeclaration declaration : declarations) {
            if (declaration instanceof KtClassOrObject || declaration instanceof KtTypeAlias) {
                return false;
            }

            if (isExtension(declaration)) {
                hasExtension = true;
            }
        }

        return hasExtension;
    }

    static boolean isExtension(KtDeclaration declaration) {
        if (declaration instanceof KtNamedFunction function) {
            return function.getReceiverTypeReference() != null;
        }

        return declaration instanceof KtProperty property && property.getReceiverTypeReference() != null;
    }

    /** K2。公開と internal の区画の中は、公開・internal の順にする。private は K1 が見る。 */
    static List<LayoutFinding> accessOrder(LayoutSource source, List<KtDeclaration> declarations) {
        List<LayoutFinding> findings = new ArrayList<>();
        boolean seenInternal = false;

        for (KtDeclaration declaration : declarations) {
            if (rank(declaration, source.stem) != 3) {
                continue;
            }

            int access = LayoutDecls.access(declaration);

            if (access == LayoutDecls.INTERNAL) {
                seenInternal = true;
            } else if (access == LayoutDecls.PUBLIC && seenInternal) {
                findings.add(source.finding(declaration, "K2: 拡張だけのファイルは、公開・internal・private の順に並べる"));
            }
        }

        return findings;
    }
}
