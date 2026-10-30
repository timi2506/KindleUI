#!/usr/bin/env bash
# Cross-compile the KindleUI example apps for armv7 (both hard-float armhf and soft-float softfp)
# using Docker.
# Outputs:
#   dist/KindleShowcase         (hard-float /lib/ld-linux-armhf.so.3)
#   dist/KindleWiki             (hard-float /lib/ld-linux-armhf.so.3)
#   dist/KindleShowcase-softfp  (soft-float /lib/ld-linux.so.3)
#   dist/KindleWiki-softfp      (soft-float /lib/ld-linux.so.3)
set -euo pipefail
cd "$(dirname "$0")"

IMAGE=swift-armv7-kindle

docker build -t "$IMAGE" .

# Use a docker volume for the build dir so macOS bind mounts don't slow SwiftPM down.
# Note:
# 1. KindleShowcase & KindleWiki use KindleUI (CKindleGTK), which dlopen()s libgtk-x11-2.0.so.0 and liblipc.so.
# 2. KindleUI uses Swift's native URLSession (FoundationNetworking), which links against libcurl.so.4.
#    Ubuntu Jammy's libcurl.so.4 tags symbols with @CURL_OPENSSL_4, whereas Kindle OS's Yocto
#    /usr/lib/libcurl.so.4 exports unversioned symbols. Replacing the SDK's link-time libcurl.so
#    with an unversioned stub lets URLSession link cleanly against Kindle OS's /usr/lib/libcurl.so.4.
# 3. For soft-float (KindleShowcase-softfp / KindleWiki-softfp):
#    - CKindleGTK.c is compiled with -DKINDLE_SOFTFP=1 (__attribute__((pcs("aapcs")))) so all
#      GTK+-2.0 / GDK / Cairo float/double calls use soft-float registers (r0-r3).
#    - libm.a is linked statically (replacing libm.so) and libc's strtod/strtof family are bridged
#      between aapcs-vfp (Swift stdlib) and aapcs (soft-float libc.so.6).
#    - ELF interpreter and DT_NEEDED loader are set to /lib/ld-linux.so.3 (ld-linux.so.3), and
#      e_flags patched to EF_ARM_ABI_FLOAT_SOFT (0x5000200).
docker run --rm \
  -v "$PWD":/src \
  -v swift-armv7-build:/build \
  "$IMAGE" bash -euc '
    LIBDIR="$SDK_DIR/ubuntu-jammy/usr/lib/arm-linux-gnueabihf"
    ln -sf libstdc++.a "$SDK_DIR/ubuntu-jammy/usr/lib/gcc/arm-linux-gnueabihf/12/libstdc++.so"
    ln -sf libatomic.a "$SDK_DIR/ubuntu-jammy/usr/lib/gcc/arm-linux-gnueabihf/12/libatomic.so"

    cat << "EOF" > /tmp/curl_stub.c
void curl_easy_cleanup(void) {}
void curl_easy_getinfo(void) {}
void curl_easy_init(void) {}
void curl_easy_pause(void) {}
void curl_easy_perform(void) {}
void curl_easy_reset(void) {}
void curl_easy_setopt(void) {}
void curl_easy_strerror(void) {}
void curl_free(void) {}
void curl_global_init(void) {}
void curl_multi_add_handle(void) {}
void curl_multi_assign(void) {}
void curl_multi_cleanup(void) {}
void curl_multi_info_read(void) {}
void curl_multi_init(void) {}
void curl_multi_remove_handle(void) {}
void curl_multi_setopt(void) {}
void curl_multi_socket_action(void) {}
void curl_share_cleanup(void) {}
void curl_share_init(void) {}
void curl_share_setopt(void) {}
void curl_slist_append(void) {}
void curl_slist_free_all(void) {}
void curl_url(void) {}
void curl_url_get(void) {}
void curl_url_set(void) {}
void curl_version(void) {}
void curl_version_info(void) {}
EOF
    clang --target=armv7-unknown-linux-gnueabihf --sysroot="$SDK_DIR/ubuntu-jammy" \
      -shared -fPIC -Wl,-soname,libcurl.so.4 /tmp/curl_stub.c \
      -o "$LIBDIR/libcurl.so"
    cp "$LIBDIR/libcurl.so" "$LIBDIR/libcurl.so.4"

    # Build GLIBC <= 2.20 compatibility stubs for libdl.so.2 and libpthread.so.0
    # (Ubuntu Jammy merged libdl/libpthread into libc.so.6 under @GLIBC_2.34, whereas
    # Kindle OS firmwares with glibc 2.20 export them at @GLIBC_2.4 / @GLIBC_2.12).
    cat << "EOF" > /tmp/dl_stub.c
void* dlopen(const char* f, int m) { return 0; }
int dlclose(void* h) { return 0; }
void* dlsym(void* h, const char* s) { return 0; }
void* dlvsym(void* h, const char* s, const char* v) { return 0; }
int dladdr(const void* a, void* i) { return 0; }
char* dlerror(void) { return 0; }
EOF
    cat << "EOF" > /tmp/dl_stub.ver
GLIBC_2.4 {
  global:
    dlopen; dlclose; dlsym; dlvsym; dladdr; dlerror;
};
EOF
    clang --target=armv7-unknown-linux-gnueabihf --sysroot="$SDK_DIR/ubuntu-jammy" \
      -nostdlib -shared -fPIC -Wl,-soname,libdl.so.2 \
      -Wl,--version-script,/tmp/dl_stub.ver /tmp/dl_stub.c \
      -o /tmp/libdl.so.2

    cat << "EOF" > /tmp/pthread_stub.c
int pthread_create(void* t, const void* a, void* (*f)(void*), void* x) { return 0; }
int pthread_join(unsigned long t, void** r) { return 0; }
int pthread_detach(unsigned long t) { return 0; }
unsigned long pthread_self(void) { return 0; }
int pthread_equal(unsigned long a, unsigned long b) { return 0; }
void pthread_exit(void* r) {}
int pthread_key_create(void* k, void (*d)(void*)) { return 0; }
int pthread_key_delete(unsigned int k) { return 0; }
int pthread_setspecific(unsigned int k, const void* v) { return 0; }
void* pthread_getspecific(unsigned int k) { return 0; }
int pthread_getaffinity_np(unsigned long t, unsigned int s, void* c) { return 0; }
int pthread_setaffinity_np(unsigned long t, unsigned int s, const void* c) { return 0; }
int pthread_setname_np(unsigned long t, const char* n) { return 0; }
int pthread_getname_np(unsigned long t, char* n, unsigned int l) { return 0; }
int pthread_sigmask(int h, const void* n, void* o) { return 0; }
int pthread_kill(unsigned long t, int s) { return 0; }
int pthread_once(void* o, void (*i)(void)) { return 0; }
int pthread_mutex_init(void* m, const void* a) { return 0; }
int pthread_mutex_destroy(void* m) { return 0; }
int pthread_mutex_lock(void* m) { return 0; }
int pthread_mutex_trylock(void* m) { return 0; }
int pthread_mutex_timedlock(void* m, const void* t) { return 0; }
int pthread_mutex_unlock(void* m) { return 0; }
int pthread_mutexattr_init(void* a) { return 0; }
int pthread_mutexattr_destroy(void* a) { return 0; }
int pthread_mutexattr_settype(void* a, int t) { return 0; }
int pthread_mutexattr_gettype(const void* a, int* t) { return 0; }
int pthread_cond_init(void* c, const void* a) { return 0; }
int pthread_cond_destroy(void* c) { return 0; }
int pthread_cond_wait(void* c, void* m) { return 0; }
int pthread_cond_timedwait(void* c, void* m, const void* t) { return 0; }
int pthread_cond_signal(void* c) { return 0; }
int pthread_cond_broadcast(void* c) { return 0; }
int pthread_condattr_init(void* a) { return 0; }
int pthread_condattr_destroy(void* a) { return 0; }
int pthread_condattr_setclock(void* a, int c) { return 0; }
int pthread_rwlock_init(void* r, const void* a) { return 0; }
int pthread_rwlock_destroy(void* r) { return 0; }
int pthread_rwlock_rdlock(void* r) { return 0; }
int pthread_rwlock_tryrdlock(void* r) { return 0; }
int pthread_rwlock_wrlock(void* r) { return 0; }
int pthread_rwlock_trywrlock(void* r) { return 0; }
int pthread_rwlock_unlock(void* r) { return 0; }
int pthread_attr_init(void* a) { return 0; }
int pthread_attr_destroy(void* a) { return 0; }
int pthread_attr_getstacksize(const void* a, unsigned int* s) { return 0; }
int pthread_attr_setstacksize(void* a, unsigned int s) { return 0; }
int pthread_attr_setdetachstate(void* a, int d) { return 0; }
int pthread_getattr_np(unsigned long t, void* a) { return 0; }
void* sem_open(const char* n, int o, ...) { return 0; }
int sem_close(void* s) { return 0; }
int sem_unlink(const char* n) { return 0; }
int sem_init(void* s, int p, unsigned int v) { return 0; }
int sem_destroy(void* s) { return 0; }
int sem_post(void* s) { return 0; }
int sem_wait(void* s) { return 0; }
int sem_trywait(void* s) { return 0; }
int sem_timedwait(void* s, const void* t) { return 0; }
int sem_getvalue(void* s, int* v) { return 0; }
EOF
    cat << "EOF" > /tmp/pthread_stub.ver
GLIBC_2.4 {
  global:
    pthread_create; pthread_join; pthread_detach; pthread_self; pthread_equal; pthread_exit;
    pthread_key_create; pthread_key_delete; pthread_setspecific; pthread_getspecific;
    pthread_getaffinity_np; pthread_setaffinity_np; pthread_sigmask; pthread_kill; pthread_once;
    pthread_mutex_init; pthread_mutex_destroy; pthread_mutex_lock; pthread_mutex_trylock;
    pthread_mutex_timedlock; pthread_mutex_unlock;
    pthread_mutexattr_init; pthread_mutexattr_destroy; pthread_mutexattr_settype; pthread_mutexattr_gettype;
    pthread_cond_init; pthread_cond_destroy; pthread_cond_wait; pthread_cond_timedwait;
    pthread_cond_signal; pthread_cond_broadcast;
    pthread_condattr_init; pthread_condattr_destroy; pthread_condattr_setclock;
    pthread_rwlock_init; pthread_rwlock_destroy; pthread_rwlock_rdlock; pthread_rwlock_tryrdlock;
    pthread_rwlock_wrlock; pthread_rwlock_trywrlock; pthread_rwlock_unlock;
    pthread_attr_init; pthread_attr_destroy; pthread_attr_getstacksize; pthread_attr_setstacksize;
    pthread_attr_setdetachstate; pthread_getattr_np;
    sem_open; sem_close; sem_unlink; sem_init; sem_destroy; sem_post; sem_wait; sem_trywait;
    sem_timedwait; sem_getvalue;
};
GLIBC_2.12 {
  global:
    pthread_setname_np; pthread_getname_np;
} GLIBC_2.4;
EOF
    clang --target=armv7-unknown-linux-gnueabihf --sysroot="$SDK_DIR/ubuntu-jammy" \
      -nostdlib -shared -fPIC -Wl,-soname,libpthread.so.0 \
      -Wl,--version-script,/tmp/pthread_stub.ver /tmp/pthread_stub.c \
      -o /tmp/libpthread.so.0

    # Build glibc <= 2.20 compatibility shim (resolves GLIBC_2.23..2.34 & GLIBC_PRIVATE symbols)
    cat << "EOF" > /tmp/glibc_compat.c
#define _GNU_SOURCE
#include <stdarg.h>
#include <stddef.h>
#include <stdint.h>
#include <pthread.h>
#include <dirent.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/stat.h>

/* 1. __libc_start_main@GLIBC_2.4 bridge that executes .init_array on glibc < 2.34 */
extern void (*__preinit_array_start[])(int, char**, char**) __attribute__((weak, visibility("hidden")));
extern void (*__preinit_array_end[])(int, char**, char**) __attribute__((weak, visibility("hidden")));
extern void (*__init_array_start[])(int, char**, char**) __attribute__((weak, visibility("hidden")));
extern void (*__init_array_end[])(int, char**, char**) __attribute__((weak, visibility("hidden")));
extern void _init(void) __attribute__((weak));

static void kindle_csu_init(int argc, char** argv, char** envp) {
    if (_init) {
        _init();
    }
    size_t count = (size_t)(__init_array_end - __init_array_start);
    for (size_t i = 0; i < count; i++) {
        (*__init_array_start[i])(argc, argv, envp);
    }
}

static void kindle_csu_fini(void) {}

extern int compat_libc_start_main(
    int (*main_fn)(int, char**, char**),
    int argc,
    char** ubp_av,
    void (*init)(int, char**, char**),
    void (*fini)(void),
    void (*rtld_fini)(void),
    void* stack_end
);
__asm__(".symver compat_libc_start_main, __libc_start_main@GLIBC_2.4");

int __wrap___libc_start_main(
    int (*main_fn)(int, char**, char**),
    int argc,
    char** ubp_av,
    void (*init)(int, char**, char**),
    void (*fini)(void),
    void (*rtld_fini)(void),
    void* stack_end
) {
    return compat_libc_start_main(
        main_fn,
        argc,
        ubp_av,
        init ? init : kindle_csu_init,
        fini ? fini : kindle_csu_fini,
        rtld_fini,
        stack_end
    );
}

/* 2. C11 <threads.h> shims over POSIX pthreads (GLIBC_2.4) */
int mtx_init(void* mutex, int type) {
    pthread_mutexattr_t attr;
    pthread_mutexattr_init(&attr);
    if (type & 1) {
        pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_RECURSIVE);
    }
    int rc = pthread_mutex_init((pthread_mutex_t*)mutex, &attr);
    pthread_mutexattr_destroy(&attr);
    return rc == 0 ? 0 : 2;
}

int mtx_lock(void* mutex) {
    return pthread_mutex_lock((pthread_mutex_t*)mutex) == 0 ? 0 : 2;
}

int mtx_unlock(void* mutex) {
    return pthread_mutex_unlock((pthread_mutex_t*)mutex) == 0 ? 0 : 2;
}

void mtx_destroy(void* mutex) {
    pthread_mutex_destroy((pthread_mutex_t*)mutex);
}

int cnd_init(void* cond) {
    return pthread_cond_init((pthread_cond_t*)cond, NULL) == 0 ? 0 : 2;
}

int cnd_wait(void* cond, void* mutex) {
    return pthread_cond_wait((pthread_cond_t*)cond, (pthread_mutex_t*)mutex) == 0 ? 0 : 2;
}

int cnd_broadcast(void* cond) {
    return pthread_cond_broadcast((pthread_cond_t*)cond) == 0 ? 0 : 2;
}

int cnd_signal(void* cond) {
    return pthread_cond_signal((pthread_cond_t*)cond) == 0 ? 0 : 2;
}

void cnd_destroy(void* cond) {
    pthread_cond_destroy((pthread_cond_t*)cond);
}

unsigned long thrd_current(void) {
    return (unsigned long)pthread_self();
}

/* 3. stat64 / fstat64 / lstat64 shims via __xstat64@GLIBC_2.4 (_STAT_VER_LINUX = 3 on arm) */
extern int __xstat64(int ver, const char* path, struct stat64* buf);
extern int __fxstat64(int ver, int fd, struct stat64* buf);
extern int __lxstat64(int ver, const char* path, struct stat64* buf);

int stat64(const char* path, struct stat64* buf) {
    return __xstat64(3, path, buf);
}
int fstat64(int fd, struct stat64* buf) {
    return __fxstat64(3, fd, buf);
}
int lstat64(const char* path, struct stat64* buf) {
    return __lxstat64(3, path, buf);
}
int __stat64(const char* path, struct stat64* buf) {
    return __xstat64(3, path, buf);
}
int __fstat64(int fd, struct stat64* buf) {
    return __fxstat64(3, fd, buf);
}
int __lstat64(const char* path, struct stat64* buf) {
    return __lxstat64(3, path, buf);
}

/* 4. fcntl64 shim via fcntl@GLIBC_2.4 */
extern int compat_fcntl(int fd, int cmd, ...);
__asm__(".symver compat_fcntl, fcntl@GLIBC_2.4");

int fcntl64(int fd, int cmd, ...) {
    va_list ap;
    va_start(ap, cmd);
    unsigned long arg = va_arg(ap, unsigned long);
    va_end(ap);
    return compat_fcntl(fd, cmd, arg);
}

/* 5. libstdc++ & Foundation compatibility symbols */
char __libc_single_threaded = 0;

int posix_spawn_file_actions_addchdir_np(void* actions, const char* path) {
    (void)actions;
    (void)path;
    return 38; /* ENOSYS */
}

/* 6. fts64_* shims forwarding to fts_*@GLIBC_2.4 and libm.a helpers */
extern void* fts_open(char* const* path_argv, int options, int (*compar)(const void*, const void*));
extern int fts_close(void* ftsp);
extern void* fts_read(void* ftsp);
extern int fts_set(void* ftsp, void* f, int instr);
extern void* fts_children(void* ftsp, int instr);

void* fts64_open(char* const* path_argv, int options, int (*compar)(const void*, const void*)) {
    return fts_open(path_argv, options, compar);
}
int fts64_close(void* ftsp) { return fts_close(ftsp); }
void* fts64_read(void* ftsp) { return fts_read(ftsp); }
int fts64_set(void* ftsp, void* f, int instr) { return fts_set(ftsp, f, instr); }
void* fts64_children(void* ftsp, int instr) { return fts_children(ftsp, instr); }

__attribute__((visibility("hidden"))) __thread int errno = 0;
__attribute__((visibility("hidden"))) __thread int __libc_errno = 0;

__attribute__((pcs("aapcs-vfp"), visibility("hidden")))
float __strtof_nan(const char* nptr, char** endptr, char end_char) {
    (void)end_char;
    if (endptr) *endptr = (char*)nptr;
    return __builtin_nanf("");
}
EOF
    clang --target=armv7-unknown-linux-gnueabihf --sysroot="$SDK_DIR/ubuntu-jammy" \
      -O2 -fPIC -c /tmp/glibc_compat.c -o /tmp/glibc_compat.o

    # Prepare static libm.a (plus float/double helpers from libc.a) so neither armhf nor softfp
    # requires GLIBC_2.27/2.29/2.35 from libm.so.6 or calls soft-float modf/scalbn in libc.so.6.
    cp "$LIBDIR/libm.a" /tmp/libm_static.a
    (cd /tmp && ar x "$LIBDIR/libc.a" s_modf.o s_scalbn.o s_frexp.o s_ldexp.o s_modff.o s_scalbnf.o s_frexpf.o s_ldexpf.o && \
      ar r /tmp/libm_static.a s_modf.o s_scalbn.o s_frexp.o s_ldexp.o s_modff.o s_scalbnf.o s_frexpf.o s_ldexpf.o)
    rm -f "$LIBDIR/libm.so"
    ln -s /tmp/libm_static.a "$LIBDIR/libm.so"

    mkdir -p /src/dist

    # 1. Build hard-float (armhf) binaries (compatible with glibc >= 2.20)
    rm -rf /build/armv7-unknown-linux-gnueabihf/release/CKindleGTK.build
    rm -f /build/release/KindleShowcase /build/release/KindleWiki
    swift build -c release --package-path /src/Examples \
      --scratch-path /build \
      --destination "$SDK_DIR/ubuntu-jammy-static.json" \
      --static-swift-stdlib \
      -Xlinker /tmp/glibc_compat.o \
      -Xlinker "$LIBDIR/libwebp.a" \
      -Xlinker /tmp/libm_static.a \
      -Xlinker --no-as-needed \
      -Xlinker /tmp/libpthread.so.0 \
      -Xlinker /tmp/libdl.so.2 \
      -Xlinker --as-needed \
      -Xlinker --wrap=__libc_start_main \
      -Xlinker --strip-all
    for app in KindleShowcase KindleWiki; do
      cp /build/release/$app /src/dist/$app
    done

    # 2. Build soft-float (softfp / arm-linux-gnueabi ABI) binaries
    cat << "EOF" > /tmp/softfp_bridge.c
#include <locale.h>

extern double __real_strtod(const char* nptr, char** endptr) __attribute__((pcs("aapcs")));
extern float __real_strtof(const char* nptr, char** endptr) __attribute__((pcs("aapcs")));
extern long double __real_strtold(const char* nptr, char** endptr) __attribute__((pcs("aapcs")));
extern double __real___strtod_l(const char* nptr, char** endptr, locale_t loc) __attribute__((pcs("aapcs")));
extern float __real___strtof_l(const char* nptr, char** endptr, locale_t loc) __attribute__((pcs("aapcs")));
extern long double __real___strtold_l(const char* nptr, char** endptr, locale_t loc) __attribute__((pcs("aapcs")));
extern double __real_strtod_l(const char* nptr, char** endptr, locale_t loc) __attribute__((pcs("aapcs")));
extern float __real_strtof_l(const char* nptr, char** endptr, locale_t loc) __attribute__((pcs("aapcs")));
extern long double __real_strtold_l(const char* nptr, char** endptr, locale_t loc) __attribute__((pcs("aapcs")));

__attribute__((pcs("aapcs-vfp")))
double __wrap_strtod(const char* nptr, char** endptr) {
    return __real_strtod(nptr, endptr);
}

__attribute__((pcs("aapcs-vfp")))
float __wrap_strtof(const char* nptr, char** endptr) {
    return __real_strtof(nptr, endptr);
}

__attribute__((pcs("aapcs-vfp")))
long double __wrap_strtold(const char* nptr, char** endptr) {
    return __real_strtold(nptr, endptr);
}

__attribute__((pcs("aapcs-vfp")))
double __wrap___strtod_l(const char* nptr, char** endptr, locale_t loc) {
    return __real___strtod_l(nptr, endptr, loc);
}

__attribute__((pcs("aapcs-vfp")))
float __wrap___strtof_l(const char* nptr, char** endptr, locale_t loc) {
    return __real___strtof_l(nptr, endptr, loc);
}

__attribute__((pcs("aapcs-vfp")))
long double __wrap___strtold_l(const char* nptr, char** endptr, locale_t loc) {
    return __real___strtold_l(nptr, endptr, loc);
}

__attribute__((pcs("aapcs-vfp")))
double __wrap_strtod_l(const char* nptr, char** endptr, locale_t loc) {
    return __real_strtod_l(nptr, endptr, loc);
}

__attribute__((pcs("aapcs-vfp")))
float __wrap_strtof_l(const char* nptr, char** endptr, locale_t loc) {
    return __real_strtof_l(nptr, endptr, loc);
}

__attribute__((pcs("aapcs-vfp")))
long double __wrap_strtold_l(const char* nptr, char** endptr, locale_t loc) {
    return __real_strtold_l(nptr, endptr, loc);
}
EOF
    clang --target=armv7-unknown-linux-gnueabihf --sysroot="$SDK_DIR/ubuntu-jammy" \
      -O2 -fPIC -c /tmp/softfp_bridge.c -o /tmp/softfp_bridge.o

    # Create a link-time ld-linux.so.3 stub with SONAME ld-linux.so.3 so DT_NEEDED uses ld-linux.so.3
    cat << "EOF" > /tmp/ld_stub.c
void* __stack_chk_guard = 0;
void* __libc_stack_end = 0;
void* _r_debug = 0;
void* __tls_get_addr(void* ti) { return 0; }
void _dl_mcount(void) {}
EOF
    cat << "EOF" > /tmp/ld_stub.ver
GLIBC_2.4 {
  global:
    __stack_chk_guard;
    __libc_stack_end;
    _r_debug;
    __tls_get_addr;
    _dl_mcount;
};
EOF
    clang --target=armv7-unknown-linux-gnueabihf --sysroot="$SDK_DIR/ubuntu-jammy" \
      -nostdlib -shared -fPIC -Wl,-soname,ld-linux.so.3 \
      -Wl,--version-script,/tmp/ld_stub.ver /tmp/ld_stub.c \
      -o "$SDK_DIR/ubuntu-jammy/lib/ld-linux.so.3"

    cp "$LIBDIR/libc.so" /tmp/libc.so.bak
    sed "s|/lib/ld-linux-armhf.so.3|/lib/ld-linux.so.3|g" /tmp/libc.so.bak > "$LIBDIR/libc.so"

    rm -rf /build/armv7-unknown-linux-gnueabihf/release/CKindleGTK.build
    rm -f /build/release/KindleShowcase /build/release/KindleWiki
    swift build -c release --package-path /src/Examples \
      --scratch-path /build \
      --destination "$SDK_DIR/ubuntu-jammy-static.json" \
      --static-swift-stdlib \
      -Xcc -DKINDLE_SOFTFP=1 \
      -Xlinker /tmp/glibc_compat.o \
      -Xlinker /tmp/softfp_bridge.o \
      -Xlinker "$LIBDIR/libwebp.a" \
      -Xlinker /tmp/libm_static.a \
      -Xlinker --no-as-needed \
      -Xlinker /tmp/libpthread.so.0 \
      -Xlinker /tmp/libdl.so.2 \
      -Xlinker --as-needed \
      -Xlinker --wrap=__libc_start_main \
      -Xlinker --wrap=strtod \
      -Xlinker --wrap=strtof \
      -Xlinker --wrap=strtold \
      -Xlinker --wrap=__strtod_l \
      -Xlinker --wrap=__strtof_l \
      -Xlinker --wrap=__strtold_l \
      -Xlinker --wrap=strtod_l \
      -Xlinker --wrap=strtof_l \
      -Xlinker --wrap=strtold_l \
      -Xlinker --dynamic-linker \
      -Xlinker /lib/ld-linux.so.3 \
      -Xlinker --strip-all

    # Restore SDK libc.so and libm.so for future armhf builds
    cp /tmp/libc.so.bak "$LIBDIR/libc.so"
    rm -f "$LIBDIR/libm.so"
    ln -s /lib/arm-linux-gnueabihf/libm.so.6 "$LIBDIR/libm.so"

    for app in KindleShowcase KindleWiki; do
      llvm-objcopy --remove-section=.ARM.attributes /build/release/$app
      # Patch ELF e_flags (offset 36 in little-endian 32-bit ELF header):
      # Clear EF_ARM_ABI_FLOAT_HARD (0x400) and set EF_ARM_ABI_FLOAT_SOFT (0x200).
      python3 -c "
with open(\"/build/release/$app\", \"r+b\") as f:
    f.seek(36)
    flags = int.from_bytes(f.read(4), \"little\")
    flags = (flags & ~0x400) | 0x200
    f.seek(36)
    f.write(flags.to_bytes(4, \"little\"))
"
      cp /build/release/$app /src/dist/${app}-softfp
    done

    for bin in /src/dist/KindleShowcase /src/dist/KindleWiki /src/dist/KindleShowcase-softfp /src/dist/KindleWiki-softfp; do
      file "$bin" || true
      ls -lh "$bin" || true
    done
  '

echo
echo "Built: dist/KindleShowcase dist/KindleWiki dist/KindleShowcase-softfp dist/KindleWiki-softfp"
