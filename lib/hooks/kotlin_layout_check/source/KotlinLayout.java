import java.io.FileDescriptor;
import java.io.FileOutputStream;
import java.io.PrintStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;

import org.jetbrains.kotlin.cli.common.messages.MessageCollector;
import org.jetbrains.kotlin.cli.jvm.compiler.EnvironmentConfigFiles;
import org.jetbrains.kotlin.cli.jvm.compiler.KotlinCoreEnvironment;
import org.jetbrains.kotlin.com.intellij.openapi.util.Disposer;
import org.jetbrains.kotlin.config.CommonConfigurationKeys;
import org.jetbrains.kotlin.config.CompilerConfiguration;
import org.jetbrains.kotlin.psi.KtPsiFactory;

/**
 * Kotlin の並びの検査。`path:line: message` を 1 行ずつ出す。
 * 頭に --fix を渡すと、外れを直してファイルを書き換える。
 */
public final class KotlinLayout {
    private KotlinLayout() {}

    public static void main(String[] arguments) throws Exception {
        boolean fixes = arguments.length > 0 && arguments[0].equals("--fix");
        List<String> paths = List.of(arguments).subList(fixes ? 1 : 0, arguments.length);
        KtPsiFactory factory = factory();
        StringBuilder out = new StringBuilder();

        for (String path : paths) {
            String text = Files.readString(Path.of(path)).replace("\r\n", "\n");

            if (fixes) {
                String fixed = LayoutFixer.fix(path, text, factory);

                if (!fixed.equals(text)) {
                    Files.writeString(Path.of(path), fixed);
                }

                continue;
            }

            LayoutSource source = new LayoutSource(path, text, factory);

            if (source.hasErrors()) {
                continue;
            }

            for (LayoutFinding finding : findings(source)) {
                out.append(path).append(':').append(finding.line()).append(": ").append(finding.message()).append('\n');
            }
        }

        PrintStream stdout = new PrintStream(new FileOutputStream(FileDescriptor.out), true, StandardCharsets.UTF_8);
        stdout.print(out);
        stdout.flush();
        System.exit(0);
    }

    static KtPsiFactory factory() {
        CompilerConfiguration config = new CompilerConfiguration();
        config.put(CommonConfigurationKeys.MESSAGE_COLLECTOR_KEY, MessageCollector.Companion.getNONE());
        KotlinCoreEnvironment environment = KotlinCoreEnvironment.createForProduction(
            Disposer.newDisposable(),
            config,
            EnvironmentConfigFiles.JVM_CONFIG_FILES
        );
        return new KtPsiFactory(environment.getProject(), false);
    }

    static List<LayoutFinding> findings(LayoutSource source) {
        List<LayoutFinding> all = new ArrayList<>();

        all.addAll(LayoutSections.findings(source));
        all.addAll(LayoutMembers.findings(source));
        all.addAll(LayoutStatements.findings(source));
        all.addAll(LayoutLengths.findings(source));
        all.addAll(LayoutComposable.findings(source));
        all.sort(Comparator.comparingInt(LayoutFinding::line));
        return all;
    }
}
