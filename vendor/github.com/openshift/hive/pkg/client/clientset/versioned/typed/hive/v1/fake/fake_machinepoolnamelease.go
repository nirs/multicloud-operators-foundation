// Code generated by client-gen. DO NOT EDIT.

package fake

import (
	"context"

	hivev1 "github.com/openshift/hive/apis/hive/v1"
	v1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	labels "k8s.io/apimachinery/pkg/labels"
	schema "k8s.io/apimachinery/pkg/runtime/schema"
	types "k8s.io/apimachinery/pkg/types"
	watch "k8s.io/apimachinery/pkg/watch"
	testing "k8s.io/client-go/testing"
)

// FakeMachinePoolNameLeases implements MachinePoolNameLeaseInterface
type FakeMachinePoolNameLeases struct {
	Fake *FakeHiveV1
	ns   string
}

var machinepoolnameleasesResource = schema.GroupVersionResource{Group: "hive.openshift.io", Version: "v1", Resource: "machinepoolnameleases"}

var machinepoolnameleasesKind = schema.GroupVersionKind{Group: "hive.openshift.io", Version: "v1", Kind: "MachinePoolNameLease"}

// Get takes name of the machinePoolNameLease, and returns the corresponding machinePoolNameLease object, and an error if there is any.
func (c *FakeMachinePoolNameLeases) Get(ctx context.Context, name string, options v1.GetOptions) (result *hivev1.MachinePoolNameLease, err error) {
	obj, err := c.Fake.
		Invokes(testing.NewGetAction(machinepoolnameleasesResource, c.ns, name), &hivev1.MachinePoolNameLease{})

	if obj == nil {
		return nil, err
	}
	return obj.(*hivev1.MachinePoolNameLease), err
}

// List takes label and field selectors, and returns the list of MachinePoolNameLeases that match those selectors.
func (c *FakeMachinePoolNameLeases) List(ctx context.Context, opts v1.ListOptions) (result *hivev1.MachinePoolNameLeaseList, err error) {
	obj, err := c.Fake.
		Invokes(testing.NewListAction(machinepoolnameleasesResource, machinepoolnameleasesKind, c.ns, opts), &hivev1.MachinePoolNameLeaseList{})

	if obj == nil {
		return nil, err
	}

	label, _, _ := testing.ExtractFromListOptions(opts)
	if label == nil {
		label = labels.Everything()
	}
	list := &hivev1.MachinePoolNameLeaseList{ListMeta: obj.(*hivev1.MachinePoolNameLeaseList).ListMeta}
	for _, item := range obj.(*hivev1.MachinePoolNameLeaseList).Items {
		if label.Matches(labels.Set(item.Labels)) {
			list.Items = append(list.Items, item)
		}
	}
	return list, err
}

// Watch returns a watch.Interface that watches the requested machinePoolNameLeases.
func (c *FakeMachinePoolNameLeases) Watch(ctx context.Context, opts v1.ListOptions) (watch.Interface, error) {
	return c.Fake.
		InvokesWatch(testing.NewWatchAction(machinepoolnameleasesResource, c.ns, opts))

}

// Create takes the representation of a machinePoolNameLease and creates it.  Returns the server's representation of the machinePoolNameLease, and an error, if there is any.
func (c *FakeMachinePoolNameLeases) Create(ctx context.Context, machinePoolNameLease *hivev1.MachinePoolNameLease, opts v1.CreateOptions) (result *hivev1.MachinePoolNameLease, err error) {
	obj, err := c.Fake.
		Invokes(testing.NewCreateAction(machinepoolnameleasesResource, c.ns, machinePoolNameLease), &hivev1.MachinePoolNameLease{})

	if obj == nil {
		return nil, err
	}
	return obj.(*hivev1.MachinePoolNameLease), err
}

// Update takes the representation of a machinePoolNameLease and updates it. Returns the server's representation of the machinePoolNameLease, and an error, if there is any.
func (c *FakeMachinePoolNameLeases) Update(ctx context.Context, machinePoolNameLease *hivev1.MachinePoolNameLease, opts v1.UpdateOptions) (result *hivev1.MachinePoolNameLease, err error) {
	obj, err := c.Fake.
		Invokes(testing.NewUpdateAction(machinepoolnameleasesResource, c.ns, machinePoolNameLease), &hivev1.MachinePoolNameLease{})

	if obj == nil {
		return nil, err
	}
	return obj.(*hivev1.MachinePoolNameLease), err
}

// UpdateStatus was generated because the type contains a Status member.
// Add a +genclient:noStatus comment above the type to avoid generating UpdateStatus().
func (c *FakeMachinePoolNameLeases) UpdateStatus(ctx context.Context, machinePoolNameLease *hivev1.MachinePoolNameLease, opts v1.UpdateOptions) (*hivev1.MachinePoolNameLease, error) {
	obj, err := c.Fake.
		Invokes(testing.NewUpdateSubresourceAction(machinepoolnameleasesResource, "status", c.ns, machinePoolNameLease), &hivev1.MachinePoolNameLease{})

	if obj == nil {
		return nil, err
	}
	return obj.(*hivev1.MachinePoolNameLease), err
}

// Delete takes name of the machinePoolNameLease and deletes it. Returns an error if one occurs.
func (c *FakeMachinePoolNameLeases) Delete(ctx context.Context, name string, opts v1.DeleteOptions) error {
	_, err := c.Fake.
		Invokes(testing.NewDeleteActionWithOptions(machinepoolnameleasesResource, c.ns, name, opts), &hivev1.MachinePoolNameLease{})

	return err
}

// DeleteCollection deletes a collection of objects.
func (c *FakeMachinePoolNameLeases) DeleteCollection(ctx context.Context, opts v1.DeleteOptions, listOpts v1.ListOptions) error {
	action := testing.NewDeleteCollectionAction(machinepoolnameleasesResource, c.ns, listOpts)

	_, err := c.Fake.Invokes(action, &hivev1.MachinePoolNameLeaseList{})
	return err
}

// Patch applies the patch and returns the patched machinePoolNameLease.
func (c *FakeMachinePoolNameLeases) Patch(ctx context.Context, name string, pt types.PatchType, data []byte, opts v1.PatchOptions, subresources ...string) (result *hivev1.MachinePoolNameLease, err error) {
	obj, err := c.Fake.
		Invokes(testing.NewPatchSubresourceAction(machinepoolnameleasesResource, c.ns, name, pt, data, subresources...), &hivev1.MachinePoolNameLease{})

	if obj == nil {
		return nil, err
	}
	return obj.(*hivev1.MachinePoolNameLease), err
}
