#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure BeforeWrite(Cancel)
	
	Catalogs.MetadataObjectIDs.BeforeWriteObject(ThisObject);
	
EndProcedure

Procedure BeforeDelete(Cancel)
	
	Catalogs.MetadataObjectIDs.BeforeDeleteObject(ThisObject);
	
EndProcedure

#EndRegion

#EndIf
