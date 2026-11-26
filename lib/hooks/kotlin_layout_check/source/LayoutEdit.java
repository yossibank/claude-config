import java.util.Comparator;
import java.util.List;

/** 文字の範囲を置き換える編集。範囲は Java の文字の位置で数える。 */
record LayoutEdit(int start, int end, String text) {
    /** 後ろから当てる。前の編集と重なる編集は飛ばす。 */
    static String apply(List<LayoutEdit> edits, String source) {
        StringBuilder builder = new StringBuilder(source);
        int limit = source.length();
        List<LayoutEdit> sorted = edits.stream()
            .sorted(Comparator.comparingInt(LayoutEdit::start).reversed())
            .toList();

        for (LayoutEdit edit : sorted) {
            if (edit.end() > limit) {
                continue;
            }

            builder.replace(edit.start(), edit.end(), edit.text());
            limit = edit.start();
        }

        return builder.toString();
    }
}
