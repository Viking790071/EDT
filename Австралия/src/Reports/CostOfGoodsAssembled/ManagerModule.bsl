#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region InfobaseUpdate

Procedure ResetUserSettings() Export
	
	ReportsOptions.ResetUserSettings("CostOfGoodsAssembled/Default");

EndProcedure

#EndRegion

#EndIf
