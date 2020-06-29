package jwtauth

import (
	"context"
	"encoding/json"
	"github.com/onetwopunch/google-groups/fetcher"
	admin "google.golang.org/api/admin/directory/v1"
)

func (b *jwtAuthBackend) fillGoogleCustomSchemas(ctx context.Context, adminService *admin.Service, allClaims map[string]interface{}, subject, customSchemas string) error {
	userResponse, err := adminService.Users.Get(subject).Context(ctx).Projection("custom").CustomFieldMask(customSchemas).Fields("customSchemas").Do()
	if err != nil {
		return err
	}

	for schema, rawValue := range userResponse.CustomSchemas {
		// note: metadata extraction only supports strings as values, but filtering
		// happens later so we must use interface{}
		var value map[string]interface{}
		if err := json.Unmarshal(rawValue, &value); err != nil {
			return err
		}

		allClaims[schema] = value
	}

	return nil
}

// fillGoogleInfo is the equivalent of the OIDC /userinfo endpoint for GSuite
func (b *jwtAuthBackend) fillGoogleInfo(ctx context.Context, groupFetcher *fetcher.GroupFetcher, subject string, customSchemas string, allClaims map[string]interface{}, maxRecursionDepth int) (err error) {

	if customSchemas != "" {
		if err = b.fillGoogleCustomSchemas(ctx, groupFetcher.AdminService, allClaims, subject, customSchemas); err != nil {
			return err
		}
	}
	if allClaims["groups"], err = groupFetcher.ListGoogleGroups(subject, maxRecursionDepth); err != nil {
		return err
	}

	return nil
}
