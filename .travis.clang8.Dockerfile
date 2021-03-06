FROM ubuntu:18.04

RUN apt-get update && apt-get install -y ca-certificates wget gnupg2
RUN echo "deb http://apt.llvm.org/bionic/ llvm-toolchain-bionic-8 main" \
    >> /etc/apt/sources.list.d/01-llvm.list
RUN wget -O - https://apt.llvm.org/llvm-snapshot.gpg.key | apt-key add -

# Install build dependencies
RUN apt-get update && apt-get install -y \
    libllvm8 \
    llvm-8 \
    llvm-8-dev \
    llvm-8-runtime \
    clang-8 \
    clang-tools-8 \
    libclang-common-8-dev \
    libclang-8-dev \
    libclang1-8 \
    clang-format-8 \
    cmake \
    libfile-spec-native-perl \
    libgtest-dev

# Set up clang compilers
ENV CC=/usr/lib/llvm-8/bin/clang \
    CXX=/usr/lib/llvm-8/bin/clang++ \
    MAKEFLAGS="-j2"

# Fix issues with gtest installation from ubuntu debian
RUN cd /usr/src/gtest && \
    cmake . && \
    make && \
    mv libg* /usr/lib

# Fix issues with clang installation from ubuntu debian
RUN mkdir -p /usr/lib/cmake && \
    ln -s /usr/share/llvm-8/cmake /usr/lib/cmake/clang && \
    for hdr in /usr/lib/llvm-8/include/clang/*; do \
        ln -s $hdr /usr/include/clang/$(basename $hdr); \
    done && \
    ln -s /usr/lib/llvm-8/include/clang-c /usr/include/clang-c && \
    ln -s /usr/lib/llvm-8/include/llvm /usr/include/llvm && \
    ln -s /usr/lib/llvm-8/include/llvm-c /usr/include/llvm-c && \
    for lib in /usr/lib/llvm-8/lib/*; do \
        ln -s $lib /usr/lib/$(basename $lib); \
    done && \
    for bin in /usr/bin/*-8; do \
        ln -s $bin /usr/bin/$(basename $bin | rev | cut -d '-' -f2- | rev); \
    done

COPY . clangmetatool/
WORKDIR clangmetatool

# Build tool, run tests, and do a test install
RUN mkdir build && cd build && \
    cmake -DClang_DIR=/usr/share/llvm-8/cmake .. && \
    make all && \
    ctest --output-on-failure && \
    make install && \
    cd .. && rm -rf build

# Fix includes for clangmetatool (due to ubuntu debian's clang)
RUN ln -s /usr/lib/llvm-8/include/clangmetatool /usr/include/clangmetatool

# Build skeleton
RUN mkdir skeleton/build && cd skeleton/build && \
    cmake -DClang_DIR=/usr/lib/llvm-8/cmake \
          -Dclangmetatool_DIR=/usr/lib/llvm-8/lib/cmake/clang .. && \
    make all && \
    make install && \
    cd - && rm -rf skeleton/build

# Run the tool on itself
RUN yourtoolname $(find src skeleton -name '*.cpp') -- -std=gnu++14
