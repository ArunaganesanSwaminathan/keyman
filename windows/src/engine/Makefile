#
# Keyman Engine Makefile
#

# ----------------------------------------------------------------------

TARGETS=keyman32 kmcomapi keyman tsysinfox64 tsysinfo keyman64 keymanx64 mcompile inst kmtip
MANIFESTS=keyman tsysinfo tsysinfox64 keymanx64 mcompile
CLEANS=clean-engine

!include ..\Header.mak

# ----------------------------------------------------------------------

keyman: redist
    cd $(ROOT)\src\engine\keyman
    $(MAKE) $(TARGET)

kmcomapi:
    cd $(ROOT)\src\engine\kmcomapi
    $(MAKE) $(TARGET)

keyman32:
    cd $(ROOT)\src\engine\keyman32
    $(MAKE) $(TARGET)

tsysinfox64:
    cd $(ROOT)\src\engine\tsysinfox64
    $(MAKE) $(TARGET)

tsysinfo: tsysinfox64
    cd $(ROOT)\src\engine\tsysinfo
    $(MAKE) $(TARGET)

keymanx64:
    cd $(ROOT)\src\engine\keymanx64
    $(MAKE) $(TARGET)

keyman64:
    cd $(ROOT)\src\engine\keyman64
    $(MAKE) $(TARGET)

mcompile:
    cd $(ROOT)\src\engine\mcompile
    $(MAKE) $(TARGET)

kmtip:
    cd $(ROOT)\src\engine\kmtip
    $(MAKE) $(TARGET)

# ----------------------------------------------------------------------

redist:
    copy $(ROOT)\src\ext\sentry\sentry.dll $(ROOT)\bin\engine
    copy $(ROOT)\src\ext\sentry\sentry.x64.dll $(ROOT)\bin\engine
    copy $(ROOT)\src\ext\sentry\crashpad_handler.exe $(ROOT)\bin\engine

# ----------------------------------------------------------------------

inst: redist
    cd $(ROOT)\src\engine\inst
    $(MAKE) $(TARGET)

# ----------------------------------------------------------------------

clean-engine:
    cd $(ROOT)\src\engine
    -del version.txt

!include ..\Target.mak

# ----------------------------------------------------------------------
# EOF
# ----------------------------------------------------------------------
