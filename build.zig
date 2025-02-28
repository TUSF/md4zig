const std = @import("std");

const VERSION: std.SemanticVersion = .{
    .major = 0,
    .minor = 5,
    .patch = 2,
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const md4c_dep = b.dependency("md4c", .{});

    // Build Options

    // On Windows, given there is no standard lib install dir etc., we rather
    // by default build static lib.
    const build_shared = b.option(
        bool,
        "md4c-shared",
        "Build md4c as a shared library",
    ) orelse !target.result.isMinGW();
    var with_utf8 = b.option(bool, "utf8", "Use UTF8") orelse false;
    const with_utf16 = b.option(bool, "utf16", "Use UTF16") orelse false;
    const with_ascii = b.option(bool, "ascii", "Use UTF8") orelse false;

    // defaults to UTF8 if nothing else set
    if (!with_utf8 and !with_utf16 and !with_ascii) {
        with_utf8 = true;
    }

    // md4c module

    const md4c = b.addModule("md4c", .{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    md4c.addCSourceFiles(.{
        .root = md4c_dep.path(""),
        .files = &md4c_sources,
        .flags = &md4c_flags,
    });
    setDefines(md4c, with_utf8, with_utf16, with_ascii);

    const lib = b.addLibrary(.{
        .name = "md4c",
        .root_module = md4c,
        .linkage = if (build_shared) .dynamic else .static,
    });
    lib.installHeader(md4c_dep.path("src/md4c.h"), "md4c.h");
    b.installArtifact(lib);

    // md4zig module

    const md4zig = b.addModule("md4zig", .{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "md4c", .module = md4c }},
    });

    // Tests

    const lib_unit_tests = b.addTest(.{
        .root_module = md4zig,
        .target = target,
        .optimize = optimize,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}

fn setDefines(
    mod: *std.Build.Module,
    with_utf8: bool,
    with_utf16: bool,
    with_ascii: bool,
) void {
    mod.addCMacro(
        "MD_VERSION_MAJOR",
        std.fmt.comptimePrint("{d}", .{VERSION.major}),
    );
    mod.addCMacro(
        "MD_VERSION_MINOR",
        std.fmt.comptimePrint("{d}", .{VERSION.minor}),
    );
    mod.addCMacro(
        "MD_VERSION_RELEASE",
        std.fmt.comptimePrint("{d}", .{VERSION.patch}),
    );

    if (with_utf8) {
        mod.addCMacro("MD4C_USE_UTF8", "1");
    } else if (with_ascii) {
        mod.addCMacro("MD4C_USE_ASCII", "1");
    } else if (with_utf16) {
        mod.addCMacro("MD4C_USE_UTF16", "1");
    }
}

const md4c_flags = [_][]const u8{
    "-Wall",
};

const md4c_sources = [_][]const u8{
    "src/md4c.c",
};

const md2html_sources = [_][]const u8{
    "src/md4c.c",
    "src/md4c-html.c",
    "src/entity.c",
    "md2html/cmdline.c",
    "md2html/md2html.c",
};
