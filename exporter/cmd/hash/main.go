package main

import (
	"crypto/sha256"
	"exporter/pkg/utils"
	"fmt"
	"os"
)

func main() {
	// The program has parameters:
	// - 1 - the string to hash
	input := os.Args[1]

	h := sha256.New()

	hashed := utils.HashString(true, h, input)

	fmt.Printf("%s\n", hashed)

}
