{ stdenv }:

with stdenv.lib;

''
# The auto configuration with these constraints will enable most of the
# important features (RAP, UDEREF, memory sanitization).
#
# We specify virt guest rather than host here, the latter deselects e.g.,
# paravirtualization.
GRKERNSEC_CONFIG_AUTO y
GRKERNSEC_CONFIG_DESKTOP y
GRKERNSEC_CONFIG_VIRT_GUEST y
# Note: assumes platform supports CPU-level virtualization (so no pentium 4)
GRKERNSEC_CONFIG_VIRT_EPT y
GRKERNSEC_CONFIG_VIRT_KVM y
GRKERNSEC_CONFIG_PRIORITY_SECURITY y

# PaX control
PAX_SOFTMODE y
PAX_PT_PAX_FLAGS y
PAX_XATTR_PAX_FLAGS y
PAX_EI_PAX n

# The bts instrumentation method is compatible with binary only modules.
#
# Note: if platform supports SMEP, we could do without this.
PAX_KERNEXEC_PLUGIN_METHOD_BTS y

# Disable protections rendered useless by redistribution
GRKERNSEC_RANDSTRUCT n
GRKERNSEC_HIDESYM n

# Disable protections covered by vanilla mechanisms
GRKERNSEC_DMESG y
GRKERNSEC_PROC n
GRKERNSEC_KMEM n

# Disable protections that are inappropriate for a general-purpose kernel
GRKERNSEC_NO_SIMULT_CONNECT n

# Enable additional audititing
GRKERNSEC_AUDIT_PTRACE y
GRKERNSEC_AUDIT_MOUNT y
GRKERNSEC_FORKFAIL y

# Wishlist: support trusted path execution
GRKERNSEC_TPE n

# Wishlist: enable this, but breaks user initiated module loading.
GRKERNSEC_MODHARDEN n

GRKERNSEC_SYSCTL y
GRKERNSEC_SYSCTL_DISTRO y
GRKERNSEC_SYSCTL_ON y
''
