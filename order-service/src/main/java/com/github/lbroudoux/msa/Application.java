/**
 *  Copyright 2005-2016 Red Hat, Inc.
 *
 *  Red Hat licenses this file to you under the Apache License, version
 *  2.0 (the "License"); you may not use this file except in compliance
 *  with the License.  You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
 *  implied.  See the License for the specific language governing
 *  permissions and limitations under the License.
 */
package com.github.lbroudoux.msa;

import org.apache.camel.Exchange;
import org.apache.camel.builder.RouteBuilder;
import org.apache.camel.model.dataformat.JsonLibrary;
import org.apache.camel.model.rest.RestBindingMode;
import org.apache.camel.opentracing.starter.CamelOpenTracing;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.ImportResource;

/**
 * A spring-boot application that includes a Camel route builder to setup the Camel routes
 */
@SpringBootApplication
@CamelOpenTracing
@ImportResource({"classpath:spring/amq.xml", "classpath:spring/camel-context.xml"})
public class Application extends RouteBuilder {

    // must have a main method spring-boot can run
    public static void main(String[] args) {
        SpringApplication.run(Application.class, args);
    }

    @Override
    public void configure() throws Exception {
    	restConfiguration("jetty")
    		.bindingMode(RestBindingMode.json)
    		.dataFormatProperty("json.in.disableFeatures", "FAIL_ON_UNKNOWN_PROPERTIES")
			.contextPath("/api")
			.enableCORS(true)
			.port(8181)
			.endpointProperty("host","0.0.0.0")
			.endpointProperty("cors", "true")
			.endpointProperty("api.title", "MSA Store demo API")
			.endpointProperty("api.version", "1.0.0")
			.corsHeaderProperty("Access-Control-Allow-Origin", "*")
			.corsHeaderProperty("Access-Control-Allow-Methods", "GET, HEAD, POST, PUT, DELETE, TRACE, OPTIONS, CONNECT, PATCH")
			.corsHeaderProperty("Access-Control-Allow-Headers", "Origin, Accept, X-Requested-With, Content-Type, Access-Control-Request-Method, Access-Control-Request-Headers");

		rest("/shop")
			.post("/order")
				.type(Order.class)
				.to("direct:order");
		
		from("direct:order").routeId("manageOrder")
			.log("Order request processing")
			.log("Received Order body: ${body}")
			.setProperty("order", body())
			.setHeader("productId", simple("${body.product.id}"))
			//.setHeader("productId").jsonpath("$.product.id")  // When body content is a string
			.setBody(simple(null))
			.setHeader(Exchange.HTTP_METHOD, constant("GET"))
			.toD("http4://inventory-service:8080/checkAvailable/$simple{headers.productId}?"
					+ "bridgeEndpoint=true&mapHttpMessageBody=false&throwExceptionOnFailure=false")
			.log("Inventory Service response: ${body}")
			.choice()
				.when(header(Exchange.HTTP_RESPONSE_CODE).isEqualTo(200))
					.to("direct:sendShippingOrder")
				.otherwise()
					.to("direct:returnUnavailable");
		
		from("direct:sendShippingOrder").routeId("sendShippingOrder")
			.log("Sending shipping order to queue")
			// Restore order before serializing it.
			.setBody(exchangeProperty("order"))
			.marshal().json(JsonLibrary.Jackson)
			.to("amq:queue:shipping")
			.removeHeaders("JMS*")
			.setHeader(Exchange.CONTENT_TYPE, constant("text/plain"))
			.setHeader(Exchange.HTTP_RESPONSE_CODE, constant(200))
			.setBody().constant("AVAILABLE");
		
		from("direct:returnUnavailable").routeId("returnUnavailable")
			.log("Product is not available, returning error")
			.setHeader(Exchange.CONTENT_TYPE, constant("text/plain"))
			.setHeader(Exchange.HTTP_RESPONSE_CODE, constant(404))
			.setBody().constant("NOT_AVAILABLE");
	}
}
