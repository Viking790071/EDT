#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

Procedure OnReadPresentationsAtServer(Object) Export
	
	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

#EndRegion

#EndIf