// Copyright 2018 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package main

import (
	"context"
	"fmt"
	"time"

	pb "github.com/GoogleCloudPlatform/microservices-demo/src/frontend/genproto"
	"github.com/pkg/errors"
)

const (
	avoidNoopCurrencyConversionRPC = false
)

func (fe *frontendServer) getCurrencies(ctx context.Context) ([]string, error) {
	return []string{"USD", "EUR", "GBP", "JPY"}, nil
}

func (fe *frontendServer) getProducts(ctx context.Context) ([]*pb.Product, error) {
	return []*pb.Product{
		{
			Id:          "6PjHW127V9",
			Name:        "Bamboo Glass Jar",
			Description: "Beautiful bamboo glass jar for storage.",
			Picture:     "/static/img/products/bamboo-glass-jar.jpg",
			PriceUsd: &pb.Money{
				CurrencyCode: "USD",
				Units:        19,
				Nanos:        990000000,
			},
			Categories: []string{"kitchen"},
		},
		{
			Id:          "0PUK6V6EV0",
			Name:        "Candle Holder",
			Description: "Minimalist candle holder for cozy vibes.",
			Picture:     "/static/img/products/candle-holder.jpg",
			PriceUsd: &pb.Money{
				CurrencyCode: "USD",
				Units:        14,
				Nanos:        500000000,
			},
			Categories: []string{"decor"},
		},
		{
			Id:          "OLJ3QXN8GO",
			Name:        "Pro Hairdryer",
			Description: "Powerful hairdryer for professional styling.",
			Picture:     "/static/img/products/hairdryer.jpg",
			PriceUsd: &pb.Money{
				CurrencyCode: "USD",
				Units:        49,
				Nanos:        990000000,
			},
			Categories: []string{"appliances"},
		},
		{
			Id:          "66VCHSJNUP",
			Name:        "Suede Loafers",
			Description: "Comfortable suede loafers for daily wear.",
			Picture:     "/static/img/products/loafers.jpg",
			PriceUsd: &pb.Money{
				CurrencyCode: "USD",
				Units:        89,
				Nanos:        990000000,
			},
			Categories: []string{"footwear"},
		},
		{
			Id:          "1YWDNZZCDZ",
			Name:        "Retro Mug",
			Description: "Retro style ceramic mug for your coffee.",
			Picture:     "/static/img/products/mug.jpg",
			PriceUsd: &pb.Money{
				CurrencyCode: "USD",
				Units:        12,
				Nanos:        500000000,
			},
			Categories: []string{"kitchen"},
		},
		{
			Id:          "L938392OPS",
			Name:        "Salt & Pepper Shakers",
			Description: "Modern ceramic salt and pepper shakers.",
			Picture:     "/static/img/products/salt-and-pepper-shakers.jpg",
			PriceUsd: &pb.Money{
				CurrencyCode: "USD",
				Units:        18,
				Nanos:        0,
			},
			Categories: []string{"kitchen"},
		},
		{
			Id:          "sunglasses-1",
			Name:        "Classic Sunglasses",
			Description: "Timeless classic sunglasses with UV protection.",
			Picture:     "/static/img/products/sunglasses.jpg",
			PriceUsd: &pb.Money{
				CurrencyCode: "USD",
				Units:        35,
				Nanos:        0,
			},
			Categories: []string{"accessories"},
		},
		{
			Id:          "tank-top-1",
			Name:        "Cotton Tank Top",
			Description: "Soft and breathable cotton tank top.",
			Picture:     "/static/img/products/tank-top.jpg",
			PriceUsd: &pb.Money{
				CurrencyCode: "USD",
				Units:        22,
				Nanos:        0,
			},
			Categories: []string{"clothing"},
		},
		{
			Id:          "watch-1",
			Name:        "Minimalist Watch",
			Description: "Sleek minimalist analog wristwatch.",
			Picture:     "/static/img/products/watch.jpg",
			PriceUsd: &pb.Money{
				CurrencyCode: "USD",
				Units:        120,
				Nanos:        0,
			},
			Categories: []string{"accessories"},
		},
	}, nil
}

func (fe *frontendServer) getProduct(ctx context.Context, id string) (*pb.Product, error) {
	products, _ := fe.getProducts(ctx)
	for _, p := range products {
		if p.Id == id {
			return p, nil
		}
	}
	return nil, errors.New("product not found")
}

func (fe *frontendServer) getCart(ctx context.Context, userID string) ([]*pb.CartItem, error) {
	resp, err := pb.NewCartServiceClient(fe.cartSvcConn).GetCart(ctx, &pb.GetCartRequest{UserId: userID})
	return resp.GetItems(), err
}

func (fe *frontendServer) emptyCart(ctx context.Context, userID string) error {
	_, err := pb.NewCartServiceClient(fe.cartSvcConn).EmptyCart(ctx, &pb.EmptyCartRequest{UserId: userID})
	return err
}

func (fe *frontendServer) insertCart(ctx context.Context, userID, productID string, quantity int32) error {
	_, err := pb.NewCartServiceClient(fe.cartSvcConn).AddItem(ctx, &pb.AddItemRequest{
		UserId: userID,
		Item: &pb.CartItem{
			ProductId: productID,
			Quantity:  quantity},
	})
	return err
}

func (fe *frontendServer) convertCurrency(ctx context.Context, money *pb.Money, currency string) (*pb.Money, error) {
	return &pb.Money{
		CurrencyCode: currency,
		Units:        money.Units,
		Nanos:        money.Nanos,
	}, nil
}

func (fe *frontendServer) getShippingQuote(ctx context.Context, items []*pb.CartItem, currency string) (*pb.Money, error) {
	return &pb.Money{
		CurrencyCode: currency,
		Units:        15,
		Nanos:        0,
	}, nil
}

func (fe *frontendServer) getRecommendations(ctx context.Context, userID string, productIDs []string) ([]*pb.Product, error) {
	products, _ := fe.getProducts(ctx)
	// Return first 4 products as recommendations
	if len(products) > 4 {
		return products[:4], nil
	}
	return products, nil
}

func (fe *frontendServer) getAd(ctx context.Context, ctxKeys []string) ([]*pb.Ad, error) {
	return []*pb.Ad{
		{
			RedirectUrl: "/assistant",
			Text:        "Need help shopping? Try our AI assistant!",
		},
	}, nil
}

func (fe *frontendServer) placeOrder(ctx context.Context, req *pb.PlaceOrderRequest) (*pb.PlaceOrderResponse, error) {
	cart, err := fe.getCart(ctx, req.UserId)
	if err != nil {
		return nil, errors.Wrap(err, "failed to get cart during checkout")
	}

	var orderItems []*pb.OrderItem
	for _, item := range cart {
		p, err := fe.getProduct(ctx, item.GetProductId())
		if err != nil {
			return nil, errors.Wrapf(err, "failed to get product %s during checkout", item.GetProductId())
		}
		price, err := fe.convertCurrency(ctx, p.GetPriceUsd(), req.UserCurrency)
		if err != nil {
			return nil, errors.Wrapf(err, "failed to convert currency for product %s during checkout", item.GetProductId())
		}
		orderItems = append(orderItems, &pb.OrderItem{
			Item: item,
			Cost: price,
		})
	}

	// Empty the cart after successful checkout
	if err := fe.emptyCart(ctx, req.UserId); err != nil {
		return nil, errors.Wrap(err, "failed to empty cart during checkout")
	}

	return &pb.PlaceOrderResponse{
		Order: &pb.OrderResult{
			OrderId:            fmt.Sprintf("mock-order-%d", time.Now().UnixNano()),
			ShippingTrackingId: fmt.Sprintf("mock-tracking-%d", time.Now().UnixNano()),
			ShippingCost: &pb.Money{
				CurrencyCode: req.UserCurrency,
				Units:        15,
				Nanos:        0,
			},
			ShippingAddress: req.Address,
			Items:           orderItems,
		},
	}, nil
}
