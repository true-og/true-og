package nl.skbotnl.substagent;

import java.nio.charset.StandardCharsets;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public final class Hook {
    private static final Pattern PATTERN = Pattern.compile("\\$([a-zA-Z_][a-zA-Z0-9_]*)");

    private Hook() {
    }

    public static String substituteEnvVariables(String line) {
        if (line == null) {
            return null;
        }

        return PATTERN.matcher(line).replaceAll(matchResult -> {
            String env = matchResult.group(1);
            String envValue = System.getenv(env);
            if (envValue == null) {
                return Matcher.quoteReplacement(matchResult.group(0));
            }
            return Matcher.quoteReplacement(envValue);
        });
    }

    public static char[] substituteEnvVariables(char[] text) {
        if (text == null) {
            return null;
        }

        String textString = String.valueOf(text);

        String replacedString = PATTERN.matcher(textString).replaceAll(matchResult -> {
            String env = matchResult.group(1);
            String envValue = System.getenv(env);
            if (envValue == null) {
                return Matcher.quoteReplacement(matchResult.group(0));
            }
            return Matcher.quoteReplacement(envValue);
        });

        return replacedString.toCharArray();
    }

    public static byte[] substituteEnvVariables(byte[] text) {
        if (text == null) {
            return null;
        }

        String textString = new String(text, StandardCharsets.UTF_8);

        String replacedString = PATTERN.matcher(textString).replaceAll(matchResult -> {
            String env = matchResult.group(1);
            String envValue = System.getenv(env);
            if (envValue == null) {
                return Matcher.quoteReplacement(matchResult.group(0));
            }
            return Matcher.quoteReplacement(envValue);
        });

        return replacedString.getBytes(StandardCharsets.UTF_8);
    }
}
