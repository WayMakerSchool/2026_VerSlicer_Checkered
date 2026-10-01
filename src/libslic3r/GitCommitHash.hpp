#ifndef slic3r_GitCommitHash_hpp_
#define slic3r_GitCommitHash_hpp_

// libslic3r_version.h, included by the precompiled header, falls back to
// "0000000" when GIT_COMMIT_HASH is not a global compiler define. Include
// this header only from translation units that display the hash so a new
// commit does not rebuild the PCH or the rest of the libraries.
#ifdef GIT_COMMIT_HASH
#undef GIT_COMMIT_HASH
#endif
#include "git_commit_hash.h"

#endif /* slic3r_GitCommitHash_hpp_ */
