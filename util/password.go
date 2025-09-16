package util

import (
	"fmt"

	"golang.org/x/crypto/bcrypt"
)

// HashPassword returns the bycrypt hash of the password
func HashPassword(password string) (string, error) {
	hashPassword, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		return "", fmt.Errorf("faild to hash passowrd: %w", err)
	}
	return string(hashPassword), nil
}

// CheckPassowrd checks if the provided is correct or not
func CheckPassowrd(passowrd string, hashPassword string) error {
	return bcrypt.CompareHashAndPassword([]byte(hashPassword), []byte(passowrd))
}
