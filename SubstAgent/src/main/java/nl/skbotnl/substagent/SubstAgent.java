package nl.skbotnl.substagent;

import java.lang.instrument.ClassDefinition;
import java.lang.instrument.Instrumentation;
import java.util.Properties;

public final class SubstAgent {
    private SubstAgent() {
    }

    public static void premain(String agentArgs, Instrumentation inst) {
        String version = SubstAgent.class.getPackage() != null
                ? SubstAgent.class.getPackage().getImplementationVersion()
                : null;
        if (version == null || version.isBlank()) {
            version = "development";
        }
        System.out.println("[SubstAgent] Loaded version " + version);

        Transformer transformer = new Transformer();
        inst.addTransformer(transformer, false);

        if (inst.isRedefineClassesSupported() && inst.isModifiableClass(Properties.class)) {
            try {
                ClassDefinition propertiesDefinition = transformer.createPropertiesRedefinition();
                if (propertiesDefinition != null) {
                    inst.redefineClasses(propertiesDefinition);
                    System.out.println("[SubstAgent] Enabled environment variable substitution for java.util.Properties");
                }
            } catch (Exception e) {
                throw new IllegalStateException("Failed to redefine java.util.Properties", e);
            }
        } else {
            System.err.println("[SubstAgent] Class redefinition not supported for java.util.Properties; properties files will not substitute environment variables.");
        }
    }
}
