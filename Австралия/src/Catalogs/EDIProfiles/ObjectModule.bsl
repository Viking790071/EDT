#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure Filling(FillingData, FillingText, StandardProcessing)
	
	If GetFunctionalOption("UseOneCompany") Then
		Company = CommonClientServer.PredefinedItem("Catalog.Companies.MainCompany")
	EndIf;
	
	EDIProviders = Enums.EDIProviders;
	If EDIProviders.Count() = 1 Then
		Provider = EDIProviders[0];
	EndIf;
	
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	Cancel = False;
	
	
	
EndProcedure

#EndRegion

#EndIf