import java.io.BufferedReader;

 * JBoss, Home of Professional Open Source
/**
 *  Copyright 2005-2014 Red Hat, Inc.
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


public class BlueprintUnitTest extends CamelBlueprintTestSupport {
	
	private String startingPoint = "route_endpoint_uri";
	private String mockEndpoint = "route_endpoint_uri";
	private String blueprint = "OSGI-INF/blueprint/blueprint.xml";
	
	
	@Override
    protected String getBlueprintDescriptor() {
		System.setProperty("org.apache.aries.blueprint.synchronous", "true");
        return blueprint;
    }
    
	
	
	@Override
    public String isMockEndpointsAndSkip(){
		/*
		 * override this method and return the pattern for which endpoints to mock.
		 * use * to indicate all
		 * (uri1 | uri2 | uri")
		 */
        						
		return (backend); 
    }
    
    
      
    
	
    @Test
    public void doTest() throws InterruptedException {
    	  
    	
    	MockEndpoint mock = getMockEndpoint("mock:"+mockEndpoint);
    	mock.expectedMessagesMatches(new Predicate() {
	        @Override
	        public boolean matches(Exchange exchange) {
	            	return true;
	            }
        });     	   		

    	mock.returnReplyBody(new Expression() {
			String response = convertStreamToString(BlueprintUnitTest.class.getResourceAsStream("inputfile.txt") );
    		@Override
    		public <T> T evaluate(Exchange exchange, Class<T> type) {
    			return exchange.getContext().getTypeConverter().convertTo(type,response);
    			}
    	});    	
    	
    	mock.expectedMessageCount(1);
    
    	
    	
    	/* asserting response message
    	 * ========================== */    	
    	
    	RouteDefinition r = this.context().getRouteDefinition("main");
    	try {
			r.adviceWith(this.context(), new AdviceWithRouteBuilder() {

				@Override
				public void configure() throws Exception {
					this.weaveById("route_id").replace().to("mock:"+"route_id");
				}
			}
		);
			
		} catch (Exception e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		}
    	
    	MockEndpoint response=this.getMockEndpoint("mock:route_id");

    	response.expectedMessagesMatches(new Predicate() {
            @Override
            public boolean matches(Exchange exchange) {
            	return true;
            }
        });  
    	
    	
     	
    	/* ===================
    	 * Performing the test 
    	 * =================== */
    	
    	Exchange e = new DefaultExchange(this.context());
    	Message m = e.getIn();

    	m.setBody(readFromFile(BlueprintUnitTest.class.getResourceAsStream("input_request.txt"), "utf-8") );

    	e.setIn(m);
    	e.setProperty(Exchange.CHARSET_NAME, "UTF-8");
    	
    	template.send(startingPoint,e);
    	
    	
    	
    	assertMockEndpointsSatisfied(); 

    }
    
    
    static String convertStreamToString(InputStream is) {
    	System.out.println(Charset.defaultCharset().name());
        java.util.Scanner s = new java.util.Scanner(is).useDelimiter("\\A");
        return s.hasNext() ? s.next() : "";
    }
    
    static String getStringFromInputStream(InputStream in) throws Exception {
        ByteArrayOutputStream bos = new ByteArrayOutputStream();
        copyInputStream(in, bos);
        bos.close();
        return bos.toString();
    }    
    
    static void copyInputStream(InputStream in, OutputStream out) throws Exception {
        int c = 0;
        try {
            while ((c = in.read()) != -1) {
                out.write(c);
            }
        } finally {
            in.close();
        }
    }    
    
    
    public static String readFromFile(InputStream is, String code) {
    	
        StringBuilder sb = new StringBuilder(512);
        try {
            Reader r = new InputStreamReader(is, code);
            int c = 0;
            while ((c = r.read()) != -1) {
                sb.append((char) c);
            }
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
        return sb.toString();
    }

}