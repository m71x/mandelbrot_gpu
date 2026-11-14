CC = nvcc
CFLAGS = -O3
TARGET = mandelbrot

all: $(TARGET)

$(TARGET): mandelbrot.cu
	$(CC) $(CFLAGS) -o $@ $<

clean:
	rm -f $(TARGET) mandelbrot.ppm

run: $(TARGET)
	./$(TARGET)

.PHONY: all clean run