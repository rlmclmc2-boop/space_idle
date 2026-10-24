#pragma once
#include <cstdio>
#include <fstream>

// Narrow disk primitive for SaveFiles. No game state or gameplay recovery here.
class SpaceSaveIO : public RefCounted {
    GDCLASS(SpaceSaveIO, RefCounted)
protected:
    static void _bind_methods() {
        ClassDB::bind_method(D_METHOD("write_atomic", "path", "bytes"), &SpaceSaveIO::write_atomic);
    }
public:
    int write_atomic(const String &path, const PackedByteArray &bytes) const {
        String temporary = path + String(".tmp");
#ifdef _WIN32
        auto temp16 = temporary.utf16(), path16 = path.utf16();
        auto temp_name = reinterpret_cast<const wchar_t *>(temp16.get_data());
        HANDLE file = CreateFileW(temp_name, GENERIC_WRITE, 0, nullptr, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
        if (file == INVALID_HANDLE_VALUE) return 1;
        DWORD written = 0;
        bool good = bytes.size() <= DWORD(-1) && WriteFile(file, bytes.ptr(), DWORD(bytes.size()), &written, nullptr) && written == bytes.size();
        if (good) good = FlushFileBuffers(file);
        CloseHandle(file);
        if (!good) { DeleteFileW(temp_name); return 2; }
        if (!MoveFileExW(temp_name, reinterpret_cast<const wchar_t *>(path16.get_data()), MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH)) {
            DeleteFileW(temp_name); return 3;
        }
#else
        auto tmp = temporary.utf8(), dst = path.utf8();
        int file = open(tmp.get_data(), O_WRONLY | O_CREAT | O_TRUNC | O_CLOEXEC, 0600);
        if (file < 0) return 1;
        int64_t offset = 0;
        while (offset < bytes.size()) {
            auto count = ::write(file, bytes.ptr() + offset, bytes.size() - offset);
            if (count < 0 && errno == EINTR) continue;
            if (count <= 0) { close(file); unlink(tmp.get_data()); return 2; }
            offset += count;
        }
        bool good = fsync(file) == 0;
        close(file);
        if (!good) { unlink(tmp.get_data()); return 2; }
        if (::rename(tmp.get_data(),dst.get_data()) != 0) { unlink(tmp.get_data()); return 3; }
        auto parent = std::filesystem::path(dst.get_data()).parent_path();
        int directory = open(parent.c_str(), O_RDONLY | O_DIRECTORY);
        if (directory < 0) return 4;
        good = fsync(directory) == 0; close(directory);
        if (!good) return 4; // rename outcome is uncertain; caller must read back.
#endif
        return 0;
    }
};
