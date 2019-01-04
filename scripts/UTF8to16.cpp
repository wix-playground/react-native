#include <iostream>
#include <sstream>
#include <locale>
#include <string>
#include <codecvt>
#include <fstream>
#include <vector>

// Compiles on LLVM 3.3 with:
// clang++ -std=c++11 -stdlib=libc++ xxx.cpp 

using namespace std;

void readFile(const string &fileName, string& content)
{
    ifstream ifs(fileName.c_str(), ios::in | ios::binary | ios::ate);
    
    ifstream::pos_type fileSize = ifs.tellg();
    ifs.seekg(0, ios::beg);
    
    vector<char> bytes(fileSize);
    ifs.read(bytes.data(), fileSize);
    
    content = string(bytes.data(), fileSize);
}

int main (int argc, char** argv)
{
    if (argc == 2) {
        char* filename = argv[1]; // argv[1];
        string utf8;
        readFile(argv[1], utf8);

        std::wstring_convert<std::codecvt_utf8_utf16<char16_t>,char16_t> conversion;
//        std::string utf8 = conversion.to_bytes( u"\u2D30\u2D63\u2D53\u2D4D\u0021" );  // ni hao (你好)
        if (utf8.size()) {
            std::u16string utf16 = conversion.from_bytes(utf8);
            ofstream out(filename, ios::out | ios::binary);
            for (char16_t c : utf16)
//                out << (char)((int)(c) >> 8) << (char)((int)(c) & 0xFF); // big endian            
                out << (char)((int)(c) & 0xFF) << (char)((int)(c) >> 8); // little endian
            out.close();
        }
    } else {
        std::cerr << "Missing input file." << endl;
    }
    return 0;
}
