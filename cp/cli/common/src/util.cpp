// Shared CLI utility implementations.
#include "cp/cli/util.hpp"

#include <sstream>

namespace CP_NS::cli {

std::string join_args(const std::vector<std::string>& args) {
    std::ostringstream oss;
    for (std::size_t i = 0; i < args.size(); ++i) {
        if (i > 0) oss << ' ';
        oss << args[i];
    }
    return oss.str();
}

std::string make_usage(const std::string& tool, const std::vector<std::string>& options) {
    std::ostringstream oss;
    oss << "usage: " << tool;
    for (const auto& opt : options) oss << " [" << opt << "]";
    return oss.str();
}

}  // namespace CP_NS::cli
