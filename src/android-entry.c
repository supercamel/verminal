#include <sqgi_android_entry.h>
#include <glib.h>

/* Vala's shared application entry, also called by the desktop main function. */
int verminal_run(char **args, int args_length);

int sqgi_android_main(const SqgiAndroidEntryContext *context)
{
    if (!context || context->abi_version != SQGI_ANDROID_ENTRY_ABI_VERSION ||
        context->struct_size < sizeof(*context))
        return 1;

    /* The launch arguments belong to the host. GApplication may modify argv. */
    char **args = g_new0(char *, context->argc + 1);
    for (int i = 0; i < context->argc; i++)
        args[i] = g_strdup(context->argv[i]);
    int result = verminal_run(args, context->argc);
    g_strfreev(args);
    return result;
}
