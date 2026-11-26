import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.regex.Pattern;

import org.jetbrains.kotlin.com.intellij.psi.PsiComment;
import org.jetbrains.kotlin.com.intellij.psi.PsiElement;
import org.jetbrains.kotlin.com.intellij.psi.PsiErrorElement;
import org.jetbrains.kotlin.com.intellij.psi.PsiWhiteSpace;
import org.jetbrains.kotlin.psi.KtFile;
import org.jetbrains.kotlin.psi.KtPsiFactory;

/** 1 つのファイルの中身と構文木。行の数え方と、空行の足し消しの編集を作る。 */
final class LayoutSource {
    static final Pattern BLANK = Pattern.compile("\n[ \t]*\n");
    static final Pattern BLANK_RUN = Pattern.compile("\n(?:[ \t]*\n)+");

    final String stem;
    final String text;
    final KtFile file;

    private final int[] lineStarts;

    LayoutSource(String path, String text, KtPsiFactory factory) {
        String name = Path.of(path).getFileName().toString();
        int dot = name.indexOf('.');

        this.stem = dot < 0 ? name : name.substring(0, dot);
        this.text = text;
        this.file = factory.createFile(name, text);

        List<Integer> starts = new ArrayList<>();
        starts.add(0);

        for (int index = 0; index < text.length(); index++) {
            if (text.charAt(index) == '\n') {
                starts.add(index + 1);
            }
        }

        this.lineStarts = starts.stream().mapToInt(Integer::intValue).toArray();
    }

    static boolean isTrivia(PsiElement element) {
        return element instanceof PsiComment
            || element instanceof PsiWhiteSpace
            || element.getClass().getSimpleName().equals("KDocImpl");
    }

    boolean hasErrors() {
        return hasErrors(file);
    }

    int line(int offset) {
        int low = 0;
        int high = lineStarts.length - 1;

        while (low < high) {
            int middle = (low + high + 1) / 2;

            if (lineStarts[middle] <= offset) {
                low = middle;
            } else {
                high = middle - 1;
            }
        }

        return low + 1;
    }

    /** コメントと KDoc を除いた、宣言や文の頭。注釈は含む。 */
    int start(PsiElement element) {
        PsiElement child = element.getFirstChild();

        while (child != null && isTrivia(child)) {
            child = child.getNextSibling();
        }

        return child != null ? child.getTextRange().getStartOffset() : element.getTextRange().getStartOffset();
    }

    int end(PsiElement element) {
        return element.getTextRange().getEndOffset();
    }

    int startLine(PsiElement element) {
        return line(start(element));
    }

    int endLine(PsiElement element) {
        return line(Math.max(end(element) - 1, start(element)));
    }

    int lineCount(PsiElement element) {
        return endLine(element) - startLine(element) + 1;
    }

    boolean isMultiline(PsiElement element) {
        return lineCount(element) > 1;
    }

    boolean hasBlankLine(PsiElement before, PsiElement after) {
        return BLANK.matcher(text.substring(end(before), start(after))).find();
    }

    /** 前の要素との間が、空白だけか。コメントがあれば false。 */
    boolean isPlainGap(PsiElement before, PsiElement after) {
        return text.substring(end(before), after.getTextRange().getStartOffset()).isBlank();
    }

    String indent(PsiElement element) {
        int offset = element.getTextRange().getStartOffset();
        int lineStart = lineStarts[line(offset) - 1];
        String head = text.substring(lineStart, offset);
        return head.isBlank() ? head : "";
    }

    LayoutFinding finding(PsiElement at, String message) {
        return new LayoutFinding(startLine(at), message, null);
    }

    /** before と at の間に、空行を足す(inserts)か消す編集を付けた外れ。 */
    LayoutFinding finding(PsiElement before, PsiElement at, String message, boolean inserts) {
        int from = end(before);
        int to = start(at);
        String gap = text.substring(from, to);
        LayoutEdit edit;

        if (inserts) {
            int newline = gap.indexOf('\n');
            edit = newline < 0 ? null : new LayoutEdit(from + newline, from + newline, "\n");
        } else {
            edit = new LayoutEdit(from, to, BLANK_RUN.matcher(gap).replaceAll("\n"));
        }

        return new LayoutFinding(startLine(at), message, edit);
    }

    private static boolean hasErrors(PsiElement element) {
        if (element instanceof PsiErrorElement) {
            return true;
        }

        for (PsiElement child = element.getFirstChild(); child != null; child = child.getNextSibling()) {
            if (hasErrors(child)) {
                return true;
            }
        }

        return false;
    }
}
