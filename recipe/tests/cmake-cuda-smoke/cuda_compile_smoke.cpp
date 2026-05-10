#include <sycl/sycl.hpp>

int main() {
  int value = 0;
  sycl::queue queue{sycl::default_selector_v};
  sycl::buffer<int, 1> buffer{&value, sycl::range<1>{1}};

  queue.submit([&](sycl::handler& handler) {
    auto output = buffer.get_access<sycl::access::mode::write>(handler);
    handler.single_task([=]() { output[0] = 42; });
  });

  return 0;
}
