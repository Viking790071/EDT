#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Internal

Procedure OnReadPresentationsAtServer(Object) Export
	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
EndProcedure

#EndRegion

#EndIf