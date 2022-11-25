#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If DeletionMark Then
		
		DriveServer.CleanBarcodes(, Ref);
		
	EndIf;
	
	// begin Drive.FullVersion
	Catalogs.CostObjects.UpdateLinkedCostObjectsData(Ref);
	// end Drive.FullVersion
	
EndProcedure

#EndRegion

#EndIf