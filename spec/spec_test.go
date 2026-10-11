package spec_test

import (
	"path/filepath"
	"runtime"

	. "github.com/genesis-community/testkit/v2/testing"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
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

	Describe("ocfp", func() {
		Test(Environment{
			Name:        "ocfp-prometheus",
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
		Test(Environment{
			Name:        "full-github-teams",
			CloudConfig: "aws",
			CPI:         "aws",
		})
	})

	Describe("resolute", func() {
		Test(Environment{
			Name:        "resolute",
			CloudConfig: "aws",
			CPI:         "aws",
		})
		Test(Environment{
			Name:        "resolute-no-haproxy",
			CloudConfig: "aws",
			CPI:         "aws",
		})
		Test(Environment{
			Name:        "resolute-small-footprint",
			CloudConfig: "aws",
			CPI:         "aws",
		})
		Test(Environment{
			Name:        "resolute-mgmt",
			CloudConfig: "aws",
			CPI:         "aws",
		})
		Test(Environment{
			Name:        "resolute-missing-locker-release",
			CloudConfig: "aws",
			CPI:         "aws",
			OutputMatchers: OutputMatchers{
				GenesisAddSecrets: ContainSubstring("resolute_locker_release_version"),
				GenesisCheck:      ContainSubstring("resolute_locker_release_version"),
				GenesisManifest:   ContainSubstring("resolute_locker_release_version"),
			},
		})
		Test(Environment{
			Name:        "resolute-old-locker-release",
			CloudConfig: "aws",
			CPI:         "aws",
			OutputMatchers: OutputMatchers{
				GenesisAddSecrets: ContainSubstring("still calls"),
				GenesisCheck:      ContainSubstring("still calls"),
				GenesisManifest:   ContainSubstring("still calls"),
			},
		})
		Test(Environment{
			Name:        "resolute-wrong-stemcell-os",
			CloudConfig: "aws",
			CPI:         "aws",
			OutputMatchers: OutputMatchers{
				GenesisAddSecrets: ContainSubstring("stemcell os to"),
				GenesisCheck:      ContainSubstring("stemcell os to"),
				GenesisManifest:   ContainSubstring("stemcell os to"),
			},
		})
		Test(Environment{
			Name:        "resolute-stemcell-without-feature",
			CloudConfig: "aws",
			CPI:         "aws",
			OutputMatchers: OutputMatchers{
				GenesisAddSecrets: ContainSubstring("Enable the feature and remove that parameter"),
				GenesisCheck:      ContainSubstring("Enable the feature and remove that parameter"),
				GenesisManifest:   ContainSubstring("Enable the feature and remove that parameter"),
			},
		})
	})
})
