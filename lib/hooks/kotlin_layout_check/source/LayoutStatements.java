import java.util.ArrayList;
import java.util.List;
import java.util.Set;
import java.util.regex.Pattern;

import org.jetbrains.kotlin.com.intellij.psi.PsiElement;
import org.jetbrains.kotlin.lexer.KtTokens;
import org.jetbrains.kotlin.psi.KtAnnotatedExpression;
import org.jetbrains.kotlin.psi.KtAnonymousInitializer;
import org.jetbrains.kotlin.psi.KtBinaryExpression;
import org.jetbrains.kotlin.psi.KtBlockExpression;
import org.jetbrains.kotlin.psi.KtBreakExpression;
import org.jetbrains.kotlin.psi.KtCallExpression;
import org.jetbrains.kotlin.psi.KtCatchClause;
import org.jetbrains.kotlin.psi.KtClassOrObject;
import org.jetbrains.kotlin.psi.KtContainerNodeForControlStructureBody;
import org.jetbrains.kotlin.psi.KtContinueExpression;
import org.jetbrains.kotlin.psi.KtDestructuringDeclaration;
import org.jetbrains.kotlin.psi.KtExpression;
import org.jetbrains.kotlin.psi.KtFile;
import org.jetbrains.kotlin.psi.KtFunctionLiteral;
import org.jetbrains.kotlin.psi.KtIfExpression;
import org.jetbrains.kotlin.psi.KtLabeledExpression;
import org.jetbrains.kotlin.psi.KtLambdaArgument;
import org.jetbrains.kotlin.psi.KtLambdaExpression;
import org.jetbrains.kotlin.psi.KtNamedFunction;
import org.jetbrains.kotlin.psi.KtParenthesizedExpression;
import org.jetbrains.kotlin.psi.KtProperty;
import org.jetbrains.kotlin.psi.KtReturnExpression;
import org.jetbrains.kotlin.psi.KtSecondaryConstructor;
import org.jetbrains.kotlin.psi.KtThrowExpression;
import org.jetbrains.kotlin.psi.KtTryExpression;
import org.jetbrains.kotlin.psi.KtUnaryExpression;
import org.jetbrains.kotlin.psi.KtValueArgument;
import org.jetbrains.kotlin.psi.KtWhenEntry;
import org.jetbrains.kotlin.psi.KtWhenExpression;

/** K7。ブロックの中の文の空行。 */
final class LayoutStatements {
    static final int SHORT_COUNT = 3;

    /** 最後の式を値として返すラムダを受け取る呼び出し。型を見られないので、名前で推し量る。 */
    static final Set<String> VALUE_CALLEES = Set.of(
        "all", "any", "associate", "associateBy", "associateWith", "async", "compareBy", "compareByDescending",
        "coroutineScope", "count", "derivedStateOf", "distinctBy", "filter", "filterIndexed", "filterNot",
        "find", "findLast", "first", "firstNotNullOfOrNull", "firstOrNull", "flatMap", "flatMapLatest", "fold",
        "getOrElse", "getOrPut", "groupBy", "indexOfFirst", "indexOfLast", "last", "lastOrNull", "lazy", "let",
        "map", "mapIndexed", "mapIndexedNotNull", "mapKeys", "mapLatest", "mapNotNull", "mapValues", "maxByOrNull",
        "maxOf", "maxOfOrNull", "minByOrNull", "minOf", "minOfOrNull", "none", "partition", "reduce", "remember",
        "rememberSaveable", "run", "runCatching", "snapshotFlow", "sortedBy", "sortedByDescending", "sortedWith",
        "sumOf", "supervisorScope", "takeIf", "takeUnless", "update", "use", "with", "withContext",
        "withTimeout", "withTimeoutOrNull"
    );

    static final Pattern EFFECT = Pattern.compile("^[A-Z]\\w*Effect$");

    /** 結果を返さないラムダを受け取る呼び出し。 */
    static final Set<String> UNIT_CALLEES = Set.of(
        "also", "apply", "collect", "collectLatest", "forEach", "forEachIndexed", "launch", "onEach", "repeat",
        "setContent"
    );

    enum Kind { DECLARATION, ACTION, PARENT, EXIT, RESULT, BLOCK }

    /** ブロックの最後の式の値の使われ方。 */
    enum Use { VALUE, NONE, UNSURE }

    private LayoutStatements() {}

    static List<LayoutFinding> findings(LayoutSource source) {
        List<LayoutFinding> findings = new ArrayList<>();
        walk(source, source.file, false, findings);
        return findings;
    }

    static void walk(LayoutSource source, PsiElement element, boolean isSkipped, List<LayoutFinding> findings) {
        if (element instanceof KtNamedFunction function && LayoutDecls.isPreview(function)) {
            return;
        }

        boolean skips = isSkipped;

        if (element instanceof KtLambdaExpression lambda) {
            skips = isSkipped ? !isLogicInView(lambda) : isView(lambda);
        }

        if (!skips && element instanceof KtBlockExpression block && !(block.getParent() instanceof KtFile)) {
            findings.addAll(check(source, block));
        }

        for (PsiElement child = element.getFirstChild(); child != null; child = child.getNextSibling()) {
            walk(source, child, skips, findings);
        }
    }

    /** 画面を組み立てるラムダ。大文字で始まる呼び出しに渡す物で、効果と on で始まる引数は除く。 */
    static boolean isView(KtLambdaExpression lambda) {
        KtCallExpression call = callOf(lambda);

        if (call == null || isEffect(call) || isHandler(lambda)) {
            return false;
        }

        String name = LayoutDecls.calleeName(call);
        return !name.isEmpty() && Character.isUpperCase(name.charAt(0));
    }

    /** 組み立ての中で、処理を書くラムダ。効果と on で始まる引数だけを処理と見る。 */
    static boolean isLogicInView(KtLambdaExpression lambda) {
        KtCallExpression call = callOf(lambda);
        return call != null && isEffect(call) || isHandler(lambda);
    }

    static boolean isEffect(KtCallExpression call) {
        return EFFECT.matcher(LayoutDecls.calleeName(call)).matches();
    }

    static boolean isHandler(KtLambdaExpression lambda) {
        return lambda.getParent() instanceof KtValueArgument argument
            && argument.getArgumentName() != null
            && argument.getArgumentName().getAsName().asString().startsWith("on");
    }

    static KtCallExpression callOf(KtLambdaExpression lambda) {
        PsiElement parent = lambda.getParent();

        if (parent instanceof KtLambdaArgument argument && argument.getParent() instanceof KtCallExpression call) {
            return call;
        }

        if (parent instanceof KtValueArgument argument && argument.getParent() != null
            && argument.getParent().getParent() instanceof KtCallExpression call) {
            return call;
        }

        return null;
    }

    /** 中の文が複数行にわたるブロックの、外側の範囲。ラムダは波括弧を含む。 */
    static PsiElement frame(KtBlockExpression block) {
        return block.getParent() instanceof KtFunctionLiteral literal ? literal : block;
    }

    static boolean isInit(KtBlockExpression block) {
        PsiElement parent = block.getParent();
        return parent instanceof KtAnonymousInitializer || parent instanceof KtSecondaryConstructor;
    }

    /** 最後の式を値として返すブロックか。型を見られないので、決めきれない物は UNSURE にする。 */
    static Use use(KtBlockExpression block) {
        PsiElement parent = block.getParent();

        if (parent instanceof KtFunctionLiteral literal && literal.getParent() instanceof KtLambdaExpression lambda) {
            return use(lambda);
        }

        if (parent instanceof KtWhenEntry entry && entry.getParent() instanceof KtWhenExpression when) {
            return use(when);
        }

        if (parent instanceof KtContainerNodeForControlStructureBody container) {
            return container.getParent() instanceof KtIfExpression owner ? use(owner) : Use.NONE;
        }

        if (parent instanceof KtTryExpression owner) {
            return use(owner);
        }

        if (parent instanceof KtCatchClause clause && clause.getParent() instanceof KtTryExpression owner) {
            return use(owner);
        }

        return Use.NONE;
    }

    static Use use(KtLambdaExpression lambda) {
        KtCallExpression call = callOf(lambda);
        String name = call == null ? "" : LayoutDecls.calleeName(call);

        if (isHandler(lambda) || UNIT_CALLEES.contains(name) || call != null && isEffect(call)) {
            return Use.NONE;
        }

        boolean isNamed = lambda.getParent() instanceof KtValueArgument argument && argument.getArgumentName() != null;
        return !isNamed && VALUE_CALLEES.contains(name) ? Use.VALUE : Use.UNSURE;
    }

    /** 式の値が使われるか。ブロックの最後の式は、そのブロックの使われ方に従う。 */
    static Use use(KtExpression expression) {
        PsiElement parent = expression.getParent();

        if (parent instanceof KtContainerNodeForControlStructureBody container) {
            return container.getParent() instanceof KtIfExpression owner ? use(owner) : Use.NONE;
        }

        if (parent instanceof KtWhenEntry entry && entry.getParent() instanceof KtWhenExpression when) {
            return use(when);
        }

        if (parent instanceof KtParenthesizedExpression
            || parent instanceof KtAnnotatedExpression
            || parent instanceof KtLabeledExpression) {
            return use((KtExpression) parent);
        }

        if (parent instanceof KtBlockExpression block) {
            List<KtExpression> statements = block.getStatements();
            boolean isLast = !statements.isEmpty() && statements.get(statements.size() - 1) == expression;
            return isLast ? use(block) : Use.NONE;
        }

        return Use.VALUE;
    }

    static boolean isJump(KtExpression expression) {
        return expression instanceof KtReturnExpression
            || expression instanceof KtThrowExpression
            || expression instanceof KtBreakExpression
            || expression instanceof KtContinueExpression;
    }

    static boolean isAssignment(KtExpression expression) {
        if (expression instanceof KtBinaryExpression binary) {
            return KtTokens.ALL_ASSIGNMENTS.contains(binary.getOperationToken());
        }

        if (expression instanceof KtUnaryExpression unary) {
            return unary.getOperationToken() == KtTokens.PLUSPLUS || unary.getOperationToken() == KtTokens.MINUSMINUS;
        }

        return false;
    }

    static Kind kind(LayoutSource source, KtExpression statement, boolean isLast, boolean isValue) {
        if (source.isMultiline(statement) || statement instanceof KtNamedFunction || statement instanceof KtClassOrObject) {
            return Kind.BLOCK;
        }

        if (statement instanceof KtProperty || statement instanceof KtDestructuringDeclaration) {
            return Kind.DECLARATION;
        }

        if (isJump(statement)) {
            return Kind.EXIT;
        }

        if (statement instanceof KtIfExpression branch && branch.getElse() == null
            && branch.getThen() != null && isJump(branch.getThen())) {
            return Kind.EXIT;
        }

        if (statement.getText().startsWith("super.")) {
            return Kind.PARENT;
        }

        if (isLast && isValue && !isAssignment(statement)) {
            return Kind.RESULT;
        }

        return Kind.ACTION;
    }

    static List<LayoutFinding> check(LayoutSource source, KtBlockExpression block) {
        List<KtExpression> statements = block.getStatements();
        List<LayoutFinding> findings = new ArrayList<>();

        if (statements.size() < 2 || !source.isMultiline(frame(block))) {
            return findings;
        }

        Use use = use(block);
        boolean isValue = use == Use.VALUE;
        int count = statements.size();
        List<Kind> kinds = new ArrayList<>();

        for (int index = 0; index < count; index++) {
            kinds.add(kind(source, statements.get(index), index == count - 1, isValue));
        }

        boolean isInit = isInit(block);
        boolean isPlain = !kinds.contains(Kind.BLOCK) && !kinds.contains(Kind.PARENT);
        boolean isDeclarationsAndExit = kinds.get(count - 1) == Kind.EXIT
            && kinds.subList(0, count - 1).stream().allMatch(kind -> kind == Kind.DECLARATION);

        for (int index = 1; index < count; index++) {
            KtExpression before = statements.get(index - 1);
            KtExpression after = statements.get(index);
            boolean hasBlank = source.hasBlankLine(before, after);
            Kind from = kinds.get(index - 1);
            Kind to = kinds.get(index);

            boolean isUnsureEnd = use == Use.UNSURE && index == count - 1 && to == Kind.ACTION && !isAssignment(after);

            if (isUnsureEnd) {
                continue;
            }

            if (to == Kind.RESULT) {
                if (!hasBlank) {
                    findings.add(source.finding(before, after, "K7: 値を返すブロックの最後の式の前には、空行を入れる", true));
                }
            } else if (isPlain && !isInit && count <= SHORT_COUNT) {
                if (hasBlank) {
                    findings.add(source.finding(before, after, "K7: 1 行の文が 3 つまでのブロックには、空行を入れない", false));
                }
            } else if (isDeclarationsAndExit) {
                if (hasBlank) {
                    findings.add(source.finding(before, after, "K7: 1 行の val の並びと最後の return だけのブロックには、空行を入れない", false));
                }
            } else if (from == Kind.BLOCK || to == Kind.BLOCK) {
                if (!hasBlank) {
                    findings.add(source.finding(before, after, "K7: 複数行の文の前後には、空行を入れる", true));
                }
            } else if (from != to) {
                if (!hasBlank) {
                    findings.add(source.finding(before, after, "K7: 段落（準備・実行・出口）が変わる所には、空行を入れる", true));
                }
            } else if (hasBlank && !isInit) {
                findings.add(source.finding(before, after, "K7: 同じ段落の 1 行の文の間に、空行を入れない", false));
            }
        }

        return findings;
    }
}
