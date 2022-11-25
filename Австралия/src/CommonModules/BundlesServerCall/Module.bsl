
#Region Public

Function BundlePricingStrategy(Bundle) Export
	
	Return Common.ObjectAttributeValue(Bundle, "BundlePricingStrategy");
	
EndFunction

Function BundleAttributes(Bundle, BundleCharacteristic) Export
	
	Return BundlesServer.BundleAttributes(Bundle, BundleCharacteristic);
	
EndFunction

#EndRegion
