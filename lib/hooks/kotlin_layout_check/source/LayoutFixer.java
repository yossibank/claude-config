import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Objects;
import java.util.function.ToIntFunction;
import java.util.stream.IntStream;

import org.jetbrains.kotlin.com.intellij.psi.PsiElement;
import org.jetbrains.kotlin.psi.KtClassOrObject;
import org.jetbrains.kotlin.psi.KtDeclaration;
import org.jetbrains.kotlin.psi.KtPsiFactory;

/** --fix。区画の並べ替えと、空行の足し消し。動きを変える並べ替えはしない。 */
final class LayoutFixer {
    static final int MAX_PASSES = 400;

    private LayoutFixer() {}

    static String fix(String path, String text, KtPsiFactory factory) {
        String current = text;

        for (int pass = 0; pass < MAX_PASSES; pass++) {
            LayoutSource source = new LayoutSource(path, current, factory);

            if (source.hasErrors()) {
                break;
            }

            String next = pass(source);

            if (next.equals(current)) {
                break;
            }

            current = next;
        }

        return current;
    }

    static String pass(LayoutSource source) {
        LayoutEdit sections = sections(source);

        if (sections != null) {
            return LayoutEdit.apply(List.of(sections), source.text);
        }

        LayoutEdit members = members(source, source.file);

        if (members != null) {
            return LayoutEdit.apply(List.of(members), source.text);
        }

        List<LayoutEdit> blanks = KotlinLayout.findings(source).stream()
            .map(LayoutFinding::edit)
            .filter(Objects::nonNull)
            .toList();

        return LayoutEdit.apply(blanks, source.text);
    }

    /** K1・K2。ファイルの宣言を区画の順に並べ替える。 */
    static LayoutEdit sections(LayoutSource source) {
        if (source.file.isScript()) {
            return null;
        }

        List<KtDeclaration> declarations = source.file.getDeclarations();
        boolean isExtensionsOnly = LayoutSections.isExtensionsOnly(declarations);

        return reorder(source, declarations, declaration -> {
            int rank = LayoutSections.rank(declaration, source.stem);
            int access = isExtensionsOnly && rank == 3 ? LayoutDecls.access(declaration) : 0;
            return rank < 0 ? -1 : rank * 10 + access;
        });
    }

    /** K3。クラスの中の宣言を区画の順に並べ替える。1 回に 1 つのクラスだけ直す。 */
    static LayoutEdit members(LayoutSource source, PsiElement element) {
        if (element instanceof KtClassOrObject type && type.getBody() != null) {
            LayoutEdit edit = reorder(source, LayoutMembers.members(type), LayoutMembers::rank);

            if (edit != null) {
                return edit;
            }
        }

        for (PsiElement child = element.getFirstChild(); child != null; child = child.getNextSibling()) {
            LayoutEdit edit = members(source, child);

            if (edit != null) {
                return edit;
            }
        }

        return null;
    }

    /**
     * 宣言を、番号の順に丸ごと動かす。コメントや注釈は宣言に含まれて一緒に動く。
     * 宣言の間にコメントがある時と、値を作る順が変わる時は動かさない。
     */
    static LayoutEdit reorder(LayoutSource source, List<KtDeclaration> items, ToIntFunction<KtDeclaration> rank) {
        if (items.size() < 2) {
            return null;
        }

        int[] ranks = items.stream().mapToInt(rank).toArray();

        if (IntStream.of(ranks).anyMatch(value -> value < 0)) {
            return null;
        }

        for (int index = 1; index < items.size(); index++) {
            if (!source.isPlainGap(items.get(index - 1), items.get(index))) {
                return null;
            }
        }

        List<Integer> order = IntStream.range(0, items.size()).boxed()
            .sorted(Comparator.comparingInt(index -> ranks[index]))
            .toList();

        if (order.equals(IntStream.range(0, items.size()).boxed().toList())) {
            return null;
        }

        List<KtDeclaration> sorted = order.stream().map(items::get).toList();

        if (!sensitive(items).equals(sensitive(sorted))) {
            return null;
        }

        String separator = "\n\n" + source.indent(items.get(0));
        List<String> texts = new ArrayList<>();

        for (KtDeclaration item : sorted) {
            texts.add(item.getText());
        }

        int start = items.get(0).getTextRange().getStartOffset();
        int end = items.get(items.size() - 1).getTextRange().getEndOffset();

        return new LayoutEdit(start, end, String.join(separator, texts));
    }

    static List<KtDeclaration> sensitive(List<KtDeclaration> items) {
        return items.stream().filter(LayoutDecls::isOrderSensitive).toList();
    }
}
