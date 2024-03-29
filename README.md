# as-single-assembly
Set of scripts to simplify all the routine tasks that are necessary for transforming your application's shipping model to be a single binary. Once being referenced as a script invocation statement in the main project file, it will guarantee that all necessary dependencies are embedded into your main assembly afterwards on each build.

# How to use
Just add invocation statement of the ValidateEmbeddedAssembliesFunctionality.ps1 as the PreBuild task (in a same way as it could be seen in the [sample.csproj](sample.csproj) file). After that on each build you'll be provided either with an approval that the output binary is able to be shipped as a standalone module - or with the validation failures and instructions about how to fix them. The main accent of this set of tools has been made on user-friendliness and providing almost-no-time-to-fix scenarios - that's why in almost all validation failure cases you'll be provided with the code snippets and instructions where to put them in order to fix the problem.

# Validation steps
The following validation steps take step when the [ValidateEmbeddedAssembliesFunctionality.ps1](ValidateEmbeddedAssembliesFunctionality.ps1) is invoked:

* validate that app's entry point has a static constructor with the assembly resolving handler being provided to the AppDomain (and nothing more)

* verify that all project dependencies (direct or indirect) are referenced in the project as embedded resources (that should reside in the **Embedded** project's directory)

* restores all project dependencies (basically, dlls) and copies them to the **Embedded** directory of the project
