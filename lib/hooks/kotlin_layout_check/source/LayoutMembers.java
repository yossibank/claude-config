import java.util.ArrayList;
import java.util.List;
import java.util.Objects;

import org.jetbrains.kotlin.com.intellij.psi.PsiElement;
import org.jetbrains.kotlin.lexer.KtTokens;
import org.jetbrains.kotlin.psi.KtAnonymousInitializer;
import org.jetbrains.kotlin.psi.KtClassBody;
import org.jetbrains.kotlin.psi.KtClassOrObject;
import org.jetbrains.kotlin.psi.KtDeclaration;
import org.jetbrains.kotlin.psi.KtEnumEntry;
import org.jetbrains.kotlin.psi.KtFile;
import org.jetbrains.kotlin.psi.KtNamedFunction;
import org.jetbrains.kotlin.psi.KtObjectDeclaration;
import org.jetbrains.kotlin.psi.KtProperty;
import org.jetbrains.kotlin.psi.KtSecondaryConstructor;

/** K3・K4・K6。クラスの中の順、入れ子の深さ、宣言の空行。 */
final class LayoutMembers {
    static final int MAX_DEPTH = 3;
    static final List<String> MODEL_VALUES = List.of("state", "input", "output", "dependencies");
    static final List<String> MODEL_TYPES = List.of("State", "Input", "Output", "Dependencies");

    private LayoutMembers() {}

    static List<LayoutFinding> findings(LayoutSource source) {
        List<LayoutFinding> findings = new ArrayList<>();

        if (!source.file.isScript()) {
            findings.addAll(spacing(source, source.file.getDeclarations()));
        }

        walk(source, source.file, findings);
        return findings;
    }

    static void walk(LayoutSource source, PsiElement element, List<LayoutFinding> findings) {
        if (element instanceof KtClassOrObject type && type.getBody() != null) {
            List<KtDeclaration> members = members(type);

            findings.addAll(order(source, members));
            findings.addAll(spacing(source, members));
        }

        if (element instanceof KtClassOrObject type && depth(type) > MAX_DEPTH) {
            findings.add(source.finding(type, "K4: 入れ子の型は 2 段までにする"));
        }

        for (PsiElement child = element.getFirstChild(); child != null; child = child.getNextSibling()) {
            walk(source, child, findings);
        }
    }

    static List<KtDeclaration> members(KtClassOrObject type) {
        return type.getDeclarations().stream().filter(member -> !(member instanceof KtEnumEntry)).toList();
    }

    static boolean isCompanion(PsiElement element) {
        return element instanceof KtObjectDeclaration object && object.isCompanion();
    }

    /** クラスの中の区画の番号。区画に当たらない宣言は -1。 */
    static int rank(KtDeclaration member) {
        if (LayoutDecls.isStored(member) || isRequirement(member)) {
            return 0;
        }

        if (member instanceof KtAnonymousInitializer || member instanceof KtSecondaryConstructor) {
            return 1;
        }

        if (isCompanion(member)) {
            return 50;
        }

        if (member instanceof KtClassOrObject) {
            return 2;
        }

        if (member instanceof KtProperty || member instanceof KtNamedFunction) {
            return member.hasModifier(KtTokens.OVERRIDE_KEYWORD) ? 30 : 30 + LayoutDecls.access(member);
        }

        return -1;
    }

    /** interface と abstract の、本体の無いプロパティと関数。実装する側が満たす要求。 */
    static boolean isRequirement(KtDeclaration member) {
        if (member instanceof KtProperty property) {
            return LayoutDecls.isAbstract(property) && !property.hasModifier(KtTokens.OVERRIDE_KEYWORD) && property.getGetter() == null;
        }

        if (member instanceof KtNamedFunction function) {
            return !function.hasBody() && !function.hasModifier(KtTokens.OVERRIDE_KEYWORD);
        }

        return false;
    }

    static String label(int rank) {
        return switch (rank) {
            case 0 -> "保存プロパティと要求";
            case 1 -> "init と副コンストラクタ";
            case 2 -> "入れ子の型";
            case 30 -> "override の関数と計算プロパティ";
            case 31 -> "公開の関数と計算プロパティ";
            case 32 -> "internal の関数と計算プロパティ";
            case 33 -> "private の関数と計算プロパティ";
            default -> "companion object";
        };
    }

    /** K3。区画の順と、画面のモデルのまとまりの順。 */
    static List<LayoutFinding> order(LayoutSource source, List<KtDeclaration> members) {
        List<LayoutFinding> findings = new ArrayList<>();
        int highest = -1;

        for (KtDeclaration member : members) {
            int rank = rank(member);

            if (rank < 0) {
                continue;
            }

            if (rank < highest) {
                String message = "K3: クラスの中の順が違う。「" + label(rank) + "」は「" + label(highest) + "」より前に置く";
                findings.add(source.finding(member, message));
            } else {
                highest = rank;
            }
        }

        List<KtDeclaration> values = members.stream()
            .filter(member -> LayoutDecls.isStored(member) && MODEL_VALUES.contains(member.getName()))
            .toList();
        List<KtDeclaration> types = members.stream()
            .filter(member -> member instanceof KtClassOrObject && MODEL_TYPES.contains(member.getName()))
            .toList();

        findings.addAll(groupOrder(source, values, MODEL_VALUES, "K3: 画面のモデルの値は、state・input・output・dependencies の順に並べる"));
        findings.addAll(groupOrder(source, types, MODEL_TYPES, "K3: まとまりの型は、State・Input・Output・Dependencies の順に並べる"));
        return findings;
    }

    static List<LayoutFinding> groupOrder(LayoutSource source, List<KtDeclaration> members, List<String> names, String message) {
        List<LayoutFinding> findings = new ArrayList<>();

        if (members.size() < 2) {
            return findings;
        }

        int highest = -1;

        for (KtDeclaration member : members) {
            int index = names.indexOf(member.getName());

            if (index < highest) {
                findings.add(source.finding(member, message));
            } else {
                highest = index;
            }
        }

        return findings;
    }

    /** 型の段の数。自分を含め、companion と object の式は数えない。関数の中の型は 0。 */
    static int depth(KtClassOrObject type) {
        boolean isLiteral = type instanceof KtObjectDeclaration object && object.isObjectLiteral();

        if (isCompanion(type) || isLiteral || type instanceof KtEnumEntry) {
            return 0;
        }

        int depth = 1;
        PsiElement current = type.getParent();

        while (!(current instanceof KtFile)) {
            if (!(current instanceof KtClassBody) || !(current.getParent() instanceof KtClassOrObject owner)) {
                return 0;
            }

            depth += isCompanion(owner) ? 0 : 1;
            current = owner.getParent();
        }

        return depth;
    }

    /** K6。宣言の空行。 */
    static List<LayoutFinding> spacing(LayoutSource source, List<KtDeclaration> declarations) {
        List<LayoutFinding> findings = new ArrayList<>();
        List<KtDeclaration> members = declarations.stream().filter(member -> !(member instanceof KtEnumEntry)).toList();

        for (int index = 1; index < members.size(); index++) {
            KtDeclaration before = members.get(index - 1);
            KtDeclaration after = members.get(index);
            boolean hasBlank = source.hasBlankLine(before, after);
            boolean sameGroup = LayoutDecls.group(before) != null
                && Objects.equals(LayoutDecls.group(before), LayoutDecls.group(after));

            if (source.isMultiline(before) || source.isMultiline(after)) {
                if (!hasBlank) {
                    findings.add(source.finding(before, after, "K6: 複数行の宣言の前後には、空行を入れる", true));
                } else if (source.isMultiline(before) && !source.isMultiline(after) && sameGroup) {
                    findings.add(source.finding(after, "K6: 1 行の宣言は、同じまとまりの複数行の宣言より前に置く"));
                }
            } else if (hasBlank && sameGroup) {
                findings.add(source.finding(before, after, "K6: 同じまとまりの 1 行の宣言の間に、空行を入れない", false));
            }
        }

        return findings;
    }
}
