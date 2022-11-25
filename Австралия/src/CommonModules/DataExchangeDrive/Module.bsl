#Region Public

// Determines the list of exchange plans that use data exchange subsystem functionality.
//
// Parameters:
//  SubsystemExchangePlans - Array - an array of configuration exchange plans that use data exchange 
//   subsystem functionality.
//   Array elements are exchange plan metadata objects.
//
Procedure GetExchangePlans(SubsystemExchangePlans) Export
	
	SubsystemExchangePlans.Add(Metadata.ExchangePlans.Full);
	
	// begin Drive.FullVersion
	SubsystemExchangePlans.Add(Metadata.ExchangePlans.ProManage);
	// end Drive.FullVersion
	
EndProcedure

#EndRegion
