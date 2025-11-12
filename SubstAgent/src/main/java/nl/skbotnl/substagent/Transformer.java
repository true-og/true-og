package nl.skbotnl.substagent;

import javassist.ClassPool;
import javassist.CtClass;
import javassist.CtMethod;
import javassist.LoaderClassPath;

import java.lang.instrument.ClassDefinition;
import java.lang.instrument.ClassFileTransformer;
import java.security.ProtectionDomain;

class Transformer implements ClassFileTransformer {
    private static final String HOOK = Hook.class.getName();

    @Override
    public byte[] transform(
            ClassLoader loader,
            String className,
            Class<?> classBeingRedefined,
            ProtectionDomain domain,
            byte[] classfileBuffer) {
        if (className == null) {
            return null;
        }

        try {
            if ("org/yaml/snakeyaml/nodes/ScalarNode".equals(className)) {
                return transformScalarNode(loader);
            }
        } catch (Throwable e) {
            throw new IllegalStateException("Failed to transform class " + className, e);
        }

        return null;
    }

    ClassDefinition createPropertiesRedefinition() throws Exception {
        ClassPool cp = ClassPool.getDefault();
        cp.appendSystemPath();
        CtClass ctClass = cp.get("java.util.Properties");
        CtClass objectClass = cp.get("java.lang.Object");
        CtMethod putMethod = ctClass.getDeclaredMethod("put", new CtClass[]{objectClass, objectClass});
        putMethod.insertBefore("{ if ($1 instanceof String) { $1 = " + HOOK + ".substituteEnvVariables((String) $1); }" +
                " if ($2 instanceof String) { $2 = " + HOOK + ".substituteEnvVariables((String) $2); } }");
        byte[] bytecode = ctClass.toBytecode();
        ctClass.detach();
        return new ClassDefinition(Class.forName("java.util.Properties", false, null), bytecode);
    }

    private byte[] transformScalarNode(ClassLoader loader) throws Exception {
        ClassPool cp = ClassPool.getDefault();
        cp.appendSystemPath();
        if (loader != null) {
            cp.insertClassPath(new LoaderClassPath(loader));
        }
        CtClass ctClass = cp.get("org.yaml.snakeyaml.nodes.ScalarNode");
        CtMethod getValue = ctClass.getDeclaredMethod("getValue");
        getValue.insertAfter("{ if ($_ != null) { $_ = " + HOOK + ".substituteEnvVariables($_); } }");
        byte[] bytecode = ctClass.toBytecode();
        ctClass.detach();
        return bytecode;
    }
}
