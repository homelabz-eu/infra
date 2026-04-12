package sops

import (
	"bufio"
	"fmt"
	"os"
	"os/exec"
	"strings"

	"github.com/getsops/sops/v3/decrypt"
)

func DecryptFile(path string) ([]byte, error) {
	data, err := decrypt.File(path, "yaml")
	if err != nil {
		return nil, fmt.Errorf("failed to decrypt %s: %w", path, err)
	}
	return data, nil
}

func EncryptFileInPlace(path string) error {
	cmd := exec.Command("sops", "--encrypt", "--in-place", path)
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("failed to encrypt %s: %w", path, err)
	}
	return nil
}

func EditFile(path string) error {
	cmd := exec.Command("sops", path)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("sops edit failed: %w", err)
	}
	return nil
}

func IsEncrypted(path string) (bool, error) {
	f, err := os.Open(path)
	if err != nil {
		return false, err
	}
	defer f.Close()

	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		line := scanner.Text()
		if strings.HasPrefix(line, "sops:") {
			return true, nil
		}
	}
	return false, scanner.Err()
}
