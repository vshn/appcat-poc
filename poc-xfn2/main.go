package main

import (
	"flag"
	"fmt"
	"net"

	fnv1 "github.com/crossplane/function-sdk-go/proto/v1"
	"google.golang.org/grpc"
	"google.golang.org/grpc/reflection"
	"sigs.k8s.io/controller-runtime/pkg/log/zap"
)

func main() {
	addr := flag.String("addr", ":9443", "gRPC listen address")
	flag.Parse()

	lis, err := net.Listen("tcp", *addr)
	if err != nil {
		panic(fmt.Errorf("listen: %w", err))
	}

	s := grpc.NewServer()
	mgr := NewManager(zap.New())
	RegisterServices(mgr)
	fnv1.RegisterFunctionRunnerServiceServer(s, mgr)
	reflection.Register(s)

	if err := s.Serve(lis); err != nil {
		panic(fmt.Errorf("serve: %w", err))
	}
}
