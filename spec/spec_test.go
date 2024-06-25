package spec_test

import (
	"path/filepath"
	"runtime"

	. "github.com/genesis-community/testkit/v2/testing"
	. "github.com/onsi/ginkgo/v2"
)
var _ = BeforeSuite(func() {
	_, filename, _, _ := runtime.Caller(0)
	KitDir, _ = filepath.Abs(filepath.Join(filepath.Dir(filename), "../"))
})

var _ = Describe("Concourse Kit", func() {

	Describe("small-footprint", func() {
		Test(Environment{
			Name:        "small-footprint-no-tls",
			CloudConfig: "aws",
			CPI:         "aws",
		})
		// provided cert doesnt do anything
		// Test(Environment{
		// 	Name:        "small-footprint-provided-cert",
		// 	CloudConfig: "aws",
		// 	CPI:         "aws",
		// 	Focus:       true,
		// })
		Test(Environment{
			Name:        "small-footprint-self-signed-cert",
			CloudConfig: "aws",
			CPI:         "aws",
		})
		Test(Environment{
			Name:        "small-footprint-prometheus",
			CloudConfig: "aws",
			CPI:         "aws",
		})
	})

	Describe("full", func() {
		Test(Environment{
			Name:        "full-no-tls",
			CloudConfig: "aws",
			CPI:         "aws",
		})
		// provided cert doesnt do anything
		// Test(Environment{
		// 	Name:        "full-provided-cert",
		// 	CloudConfig: "aws",
		// 	CPI:         "aws",
		// 	Focus:       true,
		// })
		Test(Environment{
			Name:        "full-self-signed-cert",
			CloudConfig: "aws",
			CPI:         "aws",
		})
		Test(Environment{
			Name:        "full-all-params",
			CloudConfig: "aws",
			CPI:         "aws",
		})
	})
})
