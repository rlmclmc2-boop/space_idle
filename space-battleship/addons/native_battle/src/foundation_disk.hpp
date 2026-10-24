#pragma once
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#ifdef _WIN32
#include <windows.h>
#else
#include <fcntl.h>
#include <unistd.h>
#endif

// Only durable file replacement. Save selection, envelopes and generations
// belong to the new SaveFiles host, not to this platform primitive.
class FoundationDisk : public godot::RefCounted {
    GDCLASS(FoundationDisk, godot::RefCounted)
protected:
    static void _bind_methods() {
        godot::ClassDB::bind_method(godot::D_METHOD("replace", "temporary", "destination"), &FoundationDisk::replace);
    }
public:
    bool replace(const godot::String &temporary, const godot::String &destination) const {
#ifdef _WIN32
        auto a = temporary.utf16(), b = destination.utf16();
        const wchar_t *from = reinterpret_cast<const wchar_t *>(a.get_data());
        const wchar_t *to = reinterpret_cast<const wchar_t *>(b.get_data());
        HANDLE file = CreateFileW(from, GENERIC_WRITE, FILE_SHARE_READ, nullptr, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr);
        if (file == INVALID_HANDLE_VALUE) return false;
        bool flushed = FlushFileBuffers(file); CloseHandle(file);
        return flushed && MoveFileExW(from, to, MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH);
#else
        auto a = temporary.utf8(), b = destination.utf8();
        int file = open(a.get_data(), O_WRONLY | O_CLOEXEC);
        if (file < 0) return false;
        bool flushed = fsync(file) == 0; close(file);
        return flushed && ::rename(a.get_data(), b.get_data()) == 0;
#endif
    }
};
