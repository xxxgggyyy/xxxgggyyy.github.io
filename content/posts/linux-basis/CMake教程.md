---
title: "CMake教程"
date: 2023-02-09T20:47:57+08:00
topics: "linux-basis"
draft: true
---

# CMake教程

> 根据[官方教程](https://cmake.org/cmake/help/v3.25/guide/tutorial/index.html)(CMake2.25.2)编写

## || Step 0: 介绍

CMake是一个跨平台的构建工具。但CMake本身并不是直接向`GNU make`一样直接调用编译器和连接器，而是作为其他构建系统的中间层来实现的跨平台。

举例来说，CMake会生成对应的`makefile`或者`MSVC`工程。

### CLI基础用法

```sh
# 假设当前位置为项目源代码目录
mkdir build

# 生成对应构建系统的构建文件（工程）
# 或者cd build && cmake ..
cmake -S . -B build 

# 调用对应构建系统构建程序
cmake --build build

# 安装编译好的目标到指定位置
# 不指定prefix则安装到cmake文件中指定的位置，如`/usr/local`、`C:\Program Files`或其他用户指定目录
cmake --install build --prefix <custom_install_dir>
```

> 对于CMake来说，build文件夹又叫`binary_dir`

## || Step 1: A Basic Starting Point

> 注意，这里通过代码自身的自解释性和注释阐述大部分代码的含义

> 另外CMake的[Documention](https://cmake.org/cmake/help/v3.25/index.html)非常的有帮助，在侧边栏支持关键字搜索

### 程序清单

```sh
Step2
├── CMakeLists.txt
├── TutorialConfig.h.in
└── tutorial.cxx

0 directories, 3 files
```
> Step2即为官方给出的Step1结束后编写的所有代码

#### CMakeLists.txt

```cmake
# 任何项目的最顶层的CMakelists.txt必须以该行命令开始
cmake_minimum_required(VERSION 3.10)

# set the project name and version
# 除此之外还可以还可以设置该项目使用的编程语言等
# 应在cmake_minimum_required调用后尽快调用
project(Tutorial VERSION 1.0)

# CMAKE_开头的变量为CMake中定义的特殊变量
# 可以使用set()命令设置变量的值
# specify the C++ standard
set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED True)

# configure_file()可以实现在源代码中访问CMake变量
# 指定一个输入和输出,CMake会替换输入文件中的`@VAR@`为CMake中变量`VAR`的值
# configure a header file to pass some of the CMake settings
# to the source code
configure_file(TutorialConfig.h.in TutorialConfig.h)

# 添加一个规则（类似make的），目标为一个可执行文件，依赖为一个cpp文件
# add the executable
add_executable(Tutorial tutorial.cxx)

# 对于CMake来说它的构造结果就是`binary`
# 假设使用gcc来编译那么指定头文件包含目录是显而易见的（没有显式在#include指定绝对地址）
# add the binary tree to the search path for include files
# so that we will find TutorialConfig.h
target_include_directories(Tutorial PUBLIC
                           "${PROJECT_BINARY_DIR}"
                           )
```
`target_include_directories()`其实为目标`Tutorial`的`INCLUDE_DIRECTORIES`属性添加值。关于其参数`PUBLIC`其实要在之后的Step讲解后才好说明，这里可以出现三中值`PUBLIC|PRIVATE|INTERFACE`。

* `PRIVATE`表示只对该目标的`INCLUDE_DIRECTORIES`属性添加值
* `INTERFACE`表示对该目标的`INTERFACE_INCLUDE_DIRECTORIES`属性添加值
* `PUBLIC`则同时向这两个属性都添加。

#### TutorialConfig.h.in
```cpp
// the configured options and settings for Tutorial
// @Tutorial_VERSION_MAJOR@和@Tutorial_VERSION_MINOR@为project()命令
// 中指定version之后自动生成的变量
#define Tutorial_VERSION_MAJOR @Tutorial_VERSION_MAJOR@
#define Tutorial_VERSION_MINOR @Tutorial_VERSION_MINOR@
```

#### tutorial.cxx
```cpp
// A simple program that computes the square root of a number
#include <cmath>
#include <iostream>
#include <string>

#include "TutorialConfig.h"

int main(int argc, char* argv[])
{
  if (argc < 2) {
    // report version
    std::cout << argv[0] << " Version " << Tutorial_VERSION_MAJOR << "."
              << Tutorial_VERSION_MINOR << std::endl;
    std::cout << "Usage: " << argv[0] << " number" << std::endl;
    return 1;
  }

  // convert input to double
  const double inputValue = std::stod(argv[1]);

  // calculate square root
  const double outputValue = sqrt(inputValue);
  std::cout << "The square root of " << inputValue << " is " << outputValue
            << std::endl;
  return 0;
}
```

## || Step 2: Adding a Library

1. 将程序分块，添加一个子目录作为静态库。
2. 将该库变为可选的

### 程序清单

```sh
Step3
├── CMakeLists.txt
├── MathFunctions
│   ├── CMakeLists.txt
│   ├── MathFunctions.h
│   └── mysqrt.cxx
├── TutorialConfig.h.in
└── tutorial.cxx

1 directory, 6 files
```

#### CMakeLists.txt
```cmake

cmake_minimum_required(VERSION 3.10)

# set the project name and version
project(Tutorial VERSION 1.0)

# specify the C++ standard
set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED True)

# 添加一个布尔型的选项变量
# should we use our own math functions
option(USE_MYMATH "Use tutorial provided math implementation" ON)

# configure a header file to pass some of the CMake settings
# to the source code
configure_file(TutorialConfig.h.in TutorialConfig.h)

# 如果启用该选项则需要把子目录加到目录中
# add the MathFunctions library
if(USE_MYMATH)
  # add_subdirectory()其实就是把该目录下的CMakeLists.txt添加到该位置执行
  add_subdirectory(MathFunctions)
  # list()用来操作列表变量，这里为创建变量并追加
  list(APPEND EXTRA_LIBS MathFunctions)
  list(APPEND EXTRA_INCLUDES "${PROJECT_SOURCE_DIR}/MathFunctions")
endif()

# add the executable
add_executable(Tutorial tutorial.cxx)

# 指定需要链接的库
target_link_libraries(Tutorial PUBLIC ${EXTRA_LIBS})

# add the binary tree to the search path for include files
# so that we will find TutorialConfig.h
target_include_directories(Tutorial PUBLIC
                           "${PROJECT_BINARY_DIR}"
                           ${EXTRA_INCLUDES}
                           )
```

可以在生成`build dir`时在命令行指定选项变量的值如`cmake ../Step2 -DUSE_MYMATH=OFF`

#### MathFunctions/CMakeLists.txt
```cmake
# 增加一个库目标，依赖为mysqrt
# 这里是默认为静态库，gcc下即为多个obj组合而成的.a文件
# 在Step10会介绍如何指定STATIC|SHARED|MODULE类型的库目标
add_library(MathFunctions mysqrt.cxx)
```

理解CMake工作的关键在于理解目标和其属性。`add_executable()和add_library()`其实就是添加一个CMake生成目标，而像`target_include_directories()和target_link_libraries()`都是在操作对应目标上的对应属性，其实也可以直接使用`set_property()`，见其他节的代码实例。

#### MathFunctions/MathFunctions.h
```cpp
double mysqrt(double x);
```

#### MathFunctions/mysqrt.cxx
```cpp

#include <iostream>

#include "MathFunctions.h"

// a hack square root calculation using simple operations
double mysqrt(double x)
{
  if (x <= 0) {
    return 0;
  }

  double result = x;

  // do ten iterations
  for (int i = 0; i < 10; ++i) {
    if (result <= 0) {
      result = 0.1;
    }
    double delta = x - (result * result);
    result = result + 0.5 * delta / result;
    std::cout << "Computing sqrt of " << x << " to be " << result << std::endl;
  }
  return result;
}
```

#### TutorialConfig.h.in
```cpp
// the configured options and settings for Tutorial
#define Tutorial_VERSION_MAJOR @Tutorial_VERSION_MAJOR@
#define Tutorial_VERSION_MINOR @Tutorial_VERSION_MINOR@
// CMake中定义的选项变量的值决定其是否被替换为#define USE_MYMATH
#cmakedefine USE_MYMATH
```

#### tutorial.cxx
```cpp

// A simple program that computes the square root of a number
#include <cmath>
#include <iostream>
#include <string>

#include "TutorialConfig.h"

// should we include the MathFunctions header?
#ifdef USE_MYMATH
#  include "MathFunctions.h"
#endif

int main(int argc, char* argv[])
{
  if (argc < 2) {
    // report version
    std::cout << argv[0] << " Version " << Tutorial_VERSION_MAJOR << "."
              << Tutorial_VERSION_MINOR << std::endl;
    std::cout << "Usage: " << argv[0] << " number" << std::endl;
    return 1;
  }

  // convert input to double
  const double inputValue = std::stod(argv[1]);

  // which square root function should we use?
#ifdef USE_MYMATH
  const double outputValue = mysqrt(inputValue);
#else
  const double outputValue = sqrt(inputValue);
#endif

  std::cout << "The square root of " << inputValue << " is " << outputValue
            << std::endl;
  return 0;
}
```

## || Step 3: Adding Usage Requirements for a Library

为库定义使用要求，这样在CMake目标消费者使用该库时，会自动增加其使用要求到自己的属性中（具体见代码）。

### 程序清单
```sh
Step4
├── CMakeLists.txt
├── MathFunctions
│   ├── CMakeLists.txt
│   ├── MathFunctions.h
│   └── mysqrt.cxx
├── TutorialConfig.h.in
└── tutorial.cxx

1 directory, 6 files
```

#### CMakeLists.txt
```cmake
cmake_minimum_required(VERSION 3.10)

# set the project name and version
project(Tutorial VERSION 1.0)

# specify the C++ standard
set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED True)

# should we use our own math functions
option(USE_MYMATH "Use tutorial provided math implementation" ON)

# configure a header file to pass some of the CMake settings
# to the source code
configure_file(TutorialConfig.h.in TutorialConfig.h)

# add the MathFunctions library
if(USE_MYMATH)
  add_subdirectory(MathFunctions)
  list(APPEND EXTRA_LIBS MathFunctions)
endif()

# add the executable
add_executable(Tutorial tutorial.cxx)

# 在这里添加链接依赖时会自动把字库定义的使用要求，即要求一个包含目录，自动
# 应用到目标Tutorial上
target_link_libraries(Tutorial PUBLIC ${EXTRA_LIBS})

# add the binary tree to the search path for include files
# so that we will find TutorialConfig.h
target_include_directories(Tutorial PUBLIC
                           "${PROJECT_BINARY_DIR}"
                           )
```

### MathFunctions/CMakeLists.txt
```cmake
add_library(MathFunctions mysqrt.cxx)

# INTERFACE标志则表示了使用该库的消费者需要该包含目录
# state that anybody linking to us needs to include the current source dir
# to find MathFunctions.h, while we don't.
target_include_directories(MathFunctions
          INTERFACE ${CMAKE_CURRENT_SOURCE_DIR}
          )
```

其他文件相对于上一步，无需变化

## || Step 4: Adding Generator Expressions

目标的属性值可以用`生成器表达式`来设置。所谓的生成器表达式，就是不是常量值的意思，可以根据cmake构建的步骤来产生实际值，也用来直接生成某些信息。

该生成器表达式由三种：逻辑表达式、信息表达式、输出表达式。

比如：
```cmake
# 表示当前CMake使用的语言为cxx且编译器ID属于后面一串中的某一个，
# 则gcc_like_cxx变量则设置为真（ON等都可为真）
set(gcc_like_cxx "$<COMPILE_LANG_AND_ID:CXX,ARMClang,AppleClang,Clang,GNU,LCC>")

# BUILD_INTERFACE表示`cmake --build .`时才表示:后的值
# INSTALL_INTERFACE表示`cmake --install .`时才表示:后的值
target_include_directories(MathFunctions
                           INTERFACE
                            $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
                            $<INSTALL_INTERFACE:include>
                           )
```

> 具体某个生成器的用法参见详细的文档

### 程序清单

```sh
Step4
├── CMakeLists.txt
├── MathFunctions
│   ├── CMakeLists.txt
│   ├── MathFunctions.h
│   └── mysqrt.cxx
├── TutorialConfig.h.in
└── tutorial.cxx

1 directory, 6 files
```
#### CMakeLists.txt
```cmake

cmake_minimum_required(VERSION 3.15)

# set the project name and version
project(Tutorial VERSION 1.0)

# 通过一个完全INTERFACE的库目标来指定编译器标志
# specify the C++ standard
add_library(tutorial_compiler_flags INTERFACE)
target_compile_features(tutorial_compiler_flags INTERFACE cxx_std_11)

# 使用生成器表达式设置警告标志
# 仅在`cmake --build`时设置
# `cmake --install`安装给别人使用（假如是一个库），警告标志自然应该让使用者
# 自行设置而不是越俎代庖
# add compiler warning flags just when building this project via
# the BUILD_INTERFACE genex
set(gcc_like_cxx "$<COMPILE_LANG_AND_ID:CXX,ARMClang,AppleClang,Clang,GNU,LCC>")
set(msvc_cxx "$<COMPILE_LANG_AND_ID:CXX,MSVC>")
target_compile_options(tutorial_compiler_flags INTERFACE
  "$<${gcc_like_cxx}:$<BUILD_INTERFACE:-Wall;-Wextra;-Wshadow;-Wformat=2;-Wunused>>"
  "$<${msvc_cxx}:$<BUILD_INTERFACE:-W3>>"
)

# should we use our own math functions
option(USE_MYMATH "Use tutorial provided math implementation" ON)

# configure a header file to pass some of the CMake settings
# to the source code
configure_file(TutorialConfig.h.in TutorialConfig.h)

# add the MathFunctions library
if(USE_MYMATH)
  add_subdirectory(MathFunctions)
  list(APPEND EXTRA_LIBS MathFunctions)
endif()

# add the executable
add_executable(Tutorial tutorial.cxx)
target_link_libraries(Tutorial PUBLIC ${EXTRA_LIBS} tutorial_compiler_flags)

# add the binary tree to the search path for include files
# so that we will find TutorialConfig.h
target_include_directories(Tutorial PUBLIC
                           "${PROJECT_BINARY_DIR}"
                           )

```

#### MathFunctions/CMakeLists.txt

```cmake

add_library(MathFunctions mysqrt.cxx)

# state that anybody linking to us needs to include the current source dir
# to find MathFunctions.h, while we don't.
target_include_directories(MathFunctions
          INTERFACE ${CMAKE_CURRENT_SOURCE_DIR}
          )

# link our compiler flags interface library
target_link_libraries(MathFunctions tutorial_compiler_flags)
```

## || Step 5: Installing and Testing

安装即是将编译完成后目标安装到指定的目录。

### 程序清单

```sh
Step5
├── CMakeLists.txt
├── MathFunctions
│   ├── CMakeLists.txt
│   ├── MathFunctions.h
│   └── mysqrt.cxx
├── TutorialConfig.h.in
└── tutorial.cxx

1 directory, 6 files
```

#### CMakeLists.txt

```cmake
......

# add the install targets
install(TARGETS Tutorial DESTINATION bin)
install(FILES "${PROJECT_BINARY_DIR}/TutorialConfig.h"
  DESTINATION include
  )

# enable testing
enable_testing()

# does the application run
add_test(NAME Runs COMMAND Tutorial 25)

# does the usage message work?
add_test(NAME Usage COMMAND Tutorial)
set_tests_properties(Usage
  PROPERTIES PASS_REGULAR_EXPRESSION "Usage:.*number"
  )

# define a function to simplify adding tests
function(do_test target arg result)
  add_test(NAME Comp${arg} COMMAND ${target} ${arg})
  set_tests_properties(Comp${arg}
    PROPERTIES PASS_REGULAR_EXPRESSION ${result}
    )
endfunction()

# do a bunch of result based tests
do_test(Tutorial 4 "4 is 2")
do_test(Tutorial 9 "9 is 3")
do_test(Tutorial 5 "5 is 2.236")
do_test(Tutorial 7 "7 is 2.645")
do_test(Tutorial 25 "25 is 5")
do_test(Tutorial -25 "-25 is (-nan|nan|0)")
do_test(Tutorial 0.0001 "0.0001 is 0.01")
```

没什么好说的，但`install()`的语法最好是参考对应的文档。`install(TARGETS)`和`install(FILES)`、`instlal(EXPORT)`同样参数可能有不同含义。

#### MathFunctions/CMakeLists.txt

```cmake
......

# install libs
set(installable_libs MathFunctions tutorial_compiler_flags)
install(TARGETS ${installable_libs} DESTINATION lib)
# install include headers
install(FILES MathFunctions.h DESTINATION include)
```

## || Step 7: Adding System Introspection

CMake通过调用编译器，编译一个测试代码来检测某些系统特性是否存在

### 程序清单

#### MathFunctions/CMakeLists.txt

```cmake
......
# does this system provide the log and exp functions?
include(CheckCXXSourceCompiles)
check_cxx_source_compiles("
  #include <cmath>
  int main() {
    std::log(1.0);
    return 0;
  }
" HAVE_LOG)
check_cxx_source_compiles("
  #include <cmath>
  int main() {
    std::exp(1.0);
    return 0;
  }
" HAVE_EXP)

# 通过定义编译期宏来向源代码传递测试结果
# 比如gcc可以在命令行参数中定义宏
# add compile definitions
if(HAVE_LOG AND HAVE_EXP)
  target_compile_definitions(MathFunctions
                             PRIVATE "HAVE_LOG" "HAVE_EXP")
endif()
......
```

## || Step 8: Adding a Custom Command and Generated File


### 程序清单

#### MathFunctions/CMakeLists.txt

```cmake

# first we add the executable that generates the table
add_executable(MakeTable MakeTable.cxx)

# add the command to generate the source code
add_custom_command(
  OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/Table.h
  COMMAND MakeTable ${CMAKE_CURRENT_BINARY_DIR}/Table.h
  DEPENDS MakeTable
  )

# 在此处添加生成目标的另一个依赖`Table.h`
# 类似GNU make的递归目标生成，这里由于第一次`Table.h`不存在
# 调用`add_custom_command()`定义的命令来生成
# add the main library
add_library(MathFunctions
            mysqrt.cxx
            ${CMAKE_CURRENT_BINARY_DIR}/Table.h
            )

# state that anybody linking to us needs to include the current source dir
# to find MathFunctions.h, while we don't.
# state that we depend on Tutorial_BINARY_DIR but consumers don't, as the
# TutorialConfig.h include is an implementation detail
# state that we depend on our binary dir to find Table.h
target_include_directories(MathFunctions
          INTERFACE ${CMAKE_CURRENT_SOURCE_DIR}
          PRIVATE   ${CMAKE_CURRENT_BINARY_DIR}
          )
......
```

## || Step 9: Packaging an Installer


### 程序清单

#### CMakeLists.txt

```cmake
......
# setup installer
include(InstallRequiredSystemLibraries)
set(CPACK_RESOURCE_FILE_LICENSE "${CMAKE_CURRENT_SOURCE_DIR}/License.txt")
set(CPACK_PACKAGE_VERSION_MAJOR "${Tutorial_VERSION_MAJOR}")
set(CPACK_PACKAGE_VERSION_MINOR "${Tutorial_VERSION_MINOR}")
set(CPACK_SOURCE_GENERATOR "TGZ")
include(CPack)
```

执行`cpack`命令即可生成`install()`安装位置的打包文件

## || Step 10: Selecting Static or Shared Libraries

CMake中使用`add_library()`添加的库可以指定类型`STATIC|SHARED|MODULE|OBJECT`。

`STATIC`就是静态库，在linux下即为`.o`文件打包而成

`SHARED`即是动态链接库，但属于在程序被打开时自动加载的动态库。linux下即为`.so`

`MODULE`同样为动态链接库，但需要程序员在需要的时候手动加载的。

若`add_library()`添加库目标时没有显示的指定库类型，则为`STATIC`或者`SHARED`，此时由布尔变量`BUILD_SHARED_LIBS`控制。

### 程序清单

#### CMakeLists.txt

```cmake
......
# control where the static and shared libraries are built so that on windows
# we don't need to tinker with the path to run the executable
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY "${PROJECT_BINARY_DIR}")
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY "${PROJECT_BINARY_DIR}")
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${PROJECT_BINARY_DIR}")

option(BUILD_SHARED_LIBS "Build using shared libraries" ON)
......
```

#### MathFunctions/CMakeLists.txt

```cmake
# add the library that runs
add_library(MathFunctions MathFunctions.cxx)

# state that anybody linking to us needs to include the current source dir
# to find MathFunctions.h, while we don't.
target_include_directories(MathFunctions
                           INTERFACE ${CMAKE_CURRENT_SOURCE_DIR}
                           )

# should we use our own math functions
option(USE_MYMATH "Use tutorial provided math implementation" ON)
if(USE_MYMATH)

  target_compile_definitions(MathFunctions PRIVATE "USE_MYMATH")

  # first we add the executable that generates the table
  add_executable(MakeTable MakeTable.cxx)
  target_link_libraries(MakeTable PRIVATE tutorial_compiler_flags)

  # add the command to generate the source code
  add_custom_command(
    OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/Table.h
    COMMAND MakeTable ${CMAKE_CURRENT_BINARY_DIR}/Table.h
    DEPENDS MakeTable
    )

  # library that just does sqrt
  add_library(SqrtLibrary STATIC
              mysqrt.cxx
              ${CMAKE_CURRENT_BINARY_DIR}/Table.h
              )

  # state that we depend on our binary dir to find Table.h
  target_include_directories(SqrtLibrary PRIVATE
                             ${CMAKE_CURRENT_BINARY_DIR}
                             )

  # state that SqrtLibrary need PIC when the default is shared libraries
  set_target_properties(SqrtLibrary PROPERTIES
                        POSITION_INDEPENDENT_CODE ${BUILD_SHARED_LIBS}
                        )

  target_link_libraries(SqrtLibrary PUBLIC tutorial_compiler_flags)
  target_link_libraries(MathFunctions PRIVATE SqrtLibrary)
endif()

target_link_libraries(MathFunctions PUBLIC tutorial_compiler_flags)

# define the symbol stating we are using the declspec(dllexport) when
# building on windows
target_compile_definitions(MathFunctions PRIVATE "EXPORTING_MYMATH")
......
```

#### MathFunctions/MathFunctions.h

```cpp
#if defined(_WIN32)
#  if defined(EXPORTING_MYMATH)
#    define DECLSPEC __declspec(dllexport)
#  else
#    define DECLSPEC __declspec(dllimport)
#  endif
#else // non windows
#  define DECLSPEC
#endif

namespace mathfunctions {
double DECLSPEC sqrt(double x);
}
```

## ||Importing and Exporting Guide(Step 11: Adding Export Configuration)

> `cmake tutorial Step11`远不如`Importing and Exporting Guide`写得清晰明了

这里首先介绍如何在CMake中使用已经存在的可执行文件或者库。

然后介绍如何在CMake导出目标，即若现在有一个CMake构建的库，除了编译成功的库文文件，如何导出一个`cmake脚本（类似CMakeLists.txt格式）`,该脚本中包含构建该库的目标以及定义一些使用条件，如一来可以在其他CMake项目中快速导入该库。

此时有了该导出脚本可以很方便的引入库了，但此时也仅仅是引入，为了在引入时提供一些库版本检查、所有依赖该库的版本兼容性等其他检查特性，可以再导出一些'包'管理脚本。这样就可以使用Cmake的`find_package`来导入该库，即在上一个库导入脚本的基础上添加一些检查工作。

最后介绍CMake提供的组件功能。

### 引入目标

关键就是`IMPORTED`参数以及设置对应`IMPORTED_`属性指定位置。

```cmake
# 引入一个可执行文件作为目标，该目标不会被生成
# 然后可以通过`add_custom_command()`使用
add_executable(myexe IMPORTED)
set_property(TARGET myexe PROPERTY
             IMPORTED_LOCATION "../InstallMyExe/bin/myexe")
add_custom_command(OUTPUT main.cc COMMAND myexe)
add_executable(mynewexe main.cc)

add_library(foo STATIC IMPORTED)
set_property(TARGET foo PROPERTY
             IMPORTED_LOCATION "/path/to/libfoo.a"
# On Windows
add_library(bar SHARED IMPORTED)
set_property(TARGET bar PROPERTY
             IMPORTED_LOCATION "c:/path/to/bar.dll")
set_property(TARGET bar PROPERTY
             IMPORTED_IMPLIB "c:/path/to/bar.lib")

# 该函数到一些可能的目录寻找名为`m.lib`或者`md.lib`的库文件
# 如果找到把路经设置到第一次参数指定的变量中。
find_library(math_REL NAMES m)
find_library(math_DBG NAMES md)
add_library(math STATIC IMPORTED GLOBAL)
# 为不同的配置设置不同的地址
set_target_properties(math PROPERTIES
  IMPORTED_LOCATION "${math_REL}"
  IMPORTED_LOCATION_DEBUG "${math_DBG}"
  IMPORTED_CONFIGURATIONS "RELEASE;DEBUG"
)
```

### 导出目标

上面介绍的手动引入目标的方法，适用于导入非CMake生成的目标。而对于CMake项目构造的库（可知性文件），可在其CMakeLists.txt添加导出代码，导出`引入脚本`，这些引入脚本本质上就是上面介绍的`IMPORTED`，只不过会随着项目的安装，自动计算实际的库（可执行文件）的实际位置，以及一些额外的检查工作。

下面使用一个实例来说明：

```sh

importing-exporting/MathFunctions
├── CMakeLists.txt
├── Config.cmake.in
├── MathFunctions.cxx
└── MathFunctions.h

0 directories, 4 files
```

#### CMakeLists.txt

```cmake

cmake_minimum_required(VERSION 3.15)
project(MathFunctions)

# make cache variables for install destinations
# 以GNU的安装路径风格设置一些变量：CMAKE_INSTALL_LIBDIR等
# 具体的路径风格参见文档，除了INSTLL_PREFIX对于根目录有一些小特例，没啥太多其他作用
include(GNUInstallDirs)

# specify the C++ standard
set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED True)

# create library
add_library(MathFunctions STATIC MathFunctions.cxx)

# add include directories
# 另外CMAKE_INSTALL_INCLUDEDIR属于相对路径
# 相对于CMAKE_INSTALL_PREFIX的
# 在MathFunctionsTargets.cmake中会自动计算_IMPORTED_PREFIX，即根据当前.cmake文件的路径计算INSTALL_PREFIX，所以采用相对路径是为了可重定位，即安装文件夹可以移来移去
target_include_directories(MathFunctions
                           PUBLIC
                           "$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>"
                           "$<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>"
)

# install the target and create export-set
# EXPORT后为`导出`对象的名
# 可以使用多次，即在多个install(TARGETS)中多次使用同名
# 需要注意的是INCLUDES DESTINATION，其并非用于指定TARGETS中的包含文件的安装位置（target也没有具体的头文件只有包含路径）
# 而是用来设置导出目标需要包含的头文件路径（其实上面target_include_directories已经指定了，这里多此一举）
install(TARGETS MathFunctions
        EXPORT MathFunctionsTargets
        LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
        ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
        RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
        INCLUDES DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
)

# install header file
install(FILES MathFunctions.h DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})

# generate and install export file
# 注意在此处才真正的生成导出脚本并安装
# FILE表示可以指定导出文件名称
# NAMESPACE会加到所有的导出目标之前（仅仅如此相当于改名了）
install(EXPORT MathFunctionsTargets
        FILE MathFunctionsTargets.cmake
        NAMESPACE MathFunctions::
        DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/MathFunctions
)

# 如果就单独生成一个导出脚本而言这里已经结束了，如果需要在其他CMake项目中导入这些导出的目标，直接执行include(${INSTALL_DIR}/lib/cmake/MathFunctionsTargets.cmake)即可
# .cmake里的文件内容其实也就是CMakeLists.txt同样的语言。

# 以下生成并导出的两个文件: MathFunctionsConfig.cmake MathfunctionConfigVersion.cmake
# 其实是配合find_package()命令使用的，其在可能的目录下用包名Mathfunction搜索这两个文件并执行
# 而这两个文件无非也就是加载MathFunctionsTargets.cmake，并做一些版本和兼容性检查罢了
# include CMakePackageConfigHelpers macro
include(CMakePackageConfigHelpers)

# set version
set(version 3.4.1)

set_property(TARGET MathFunctions PROPERTY VERSION ${version})
set_property(TARGET MathFunctions PROPERTY SOVERSION 3)
# 可以设置以INTERFACE_开头的自定义属性
# COMPATIBLE_INTERFACE_STRING就是兼容性检测属性，
# 如果一个项目中多个子块都依赖了该库，则必须检查每个依赖的目标的INTERFACE_MathFunctions_MAJOR_VERSION是否相同，避免同时使用了不同版本的库

set_property(TARGET MathFunctions PROPERTY
  INTERFACE_MathFunctions_MAJOR_VERSION 3)
set_property(TARGET MathFunctions APPEND PROPERTY
  COMPATIBLE_INTERFACE_STRING MathFunctions_MAJOR_VERSION
)

# generate the version file for the config file
write_basic_package_version_file(
  "${CMAKE_CURRENT_BINARY_DIR}/MathFunctionsConfigVersion.cmake"
  VERSION "${version}"
  COMPATIBILITY AnyNewerVersion
)

# create config file
configure_package_config_file(${CMAKE_CURRENT_SOURCE_DIR}/Config.cmake.in
  "${CMAKE_CURRENT_BINARY_DIR}/MathFunctionsConfig.cmake"
  INSTALL_DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/MathFunctions
)

# install config files
install(FILES
          "${CMAKE_CURRENT_BINARY_DIR}/MathFunctionsConfig.cmake"
          "${CMAKE_CURRENT_BINARY_DIR}/MathFunctionsConfigVersion.cmake"
        DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/MathFunctions
)

# 上面的内容为将对应的cmake文件导出到了安装目录
# 但有时需要直接在build tree中使用，export()函数用当前build文件夹的
# 绝对路径导出一个MathFunctionsTargets.cmake，此时是不可重定位的
# 当然如果想要使用find_pacakge()还要额外导出对应的<Pkg>Config.cmake
# generate the export targets for the build tree
export(EXPORT MathFunctionsTargets
       FILE "${CMAKE_CURRENT_BINARY_DIR}/cmake/MathFunctionsTargets.cmake"
       NAMESPACE MathFunctions::
)
```

另外，如果：
```cmake
find_package(Stats 2.6.4 REQUIRED)
target_link_libraries(MathFunctions PUBLIC Stats::Types)
```

则必须在`Config.cmake.in`中添加：
```cmake
include(CMakeFindDependencyMacro)
# 其实就是find_package的包裹函数
find_dependency(Stats 2.6.4)
```
很好理解，link是PUBLIC的要求消费者链接该库，则消费者必须添加该依赖


## || Step 12: Packaging Debug and Release

关于配置CMake其实由两套方案，这取决于使用的generator，比如makefile这种但配置generator是由`CMAKE_BUILD_TYPE`变量在配置期间决定的即`cmake <source_dir>`。而对于支持多配置的generator则是在实际构建目标时即`cmake --build .`时决定的，而此时`CMAKE_BUILD_TYPE`被忽略，取而代之的是使用`CMAKE_CONFIGUREATION_TYPES`变量。

可采用如下生成器表达式：
```cmake
target_compile_definitions(exe1 PRIVATE
  $<$<CONFIG:Debug>:DEBUG_BUILD>
)
```

而控制不同配置输出的目标名可以采用如下方式：
```cmake
set(CMAKE_DEBUG_POSTFIX d)
set_target_properties(Tutorial PROPERTIES DEBUG_POSTFIX ${CMAKE_DEBUG_POSTFIX})
```
