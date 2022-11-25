#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

Function GetTitle(TitleParameters) Export
	
	If TitleParameters.IsManual Then
		TitlePresentation = GetTitleManual();
	Else
		TitlePresentation = GetTitleDefault();
	EndIf;
	
	IsNew = Not ValueIsFilled(TitleParameters.Ref);
	
	If IsNew Then
		
		TitlePresentation = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = '%1 %2'; ru = '%1 %2';pl = '%1 %2';es_ES = '%1 %2';es_CO = '%1 %2';tr = '%1 %2';it = '%1 %2';de = '%1 %2'"),
			TitlePresentation, NStr("en = '(create)'; ru = '(создание)';pl = '(tworzenie)';es_ES = '(crear)';es_CO = '(crear)';tr = '(oluştur)';it = '(crea)';de = '(Erstellen)'"));
		
	Else
		
		TitlePresentation = String(TitleParameters.Ref);
		
	EndIf;
	
	Return TitlePresentation;
	
EndFunction

Function GetTitleDefault() Export
	
	Return NStr("en = 'Accounting transaction'; ru = 'Бухгалтерская операция';pl = 'Transakcja księgowa';es_ES = 'Transacción contable';es_CO = 'Transacción contable';tr = 'Muhasebe işlemi';it = 'Transazione contabile';de = 'Buchhaltungstransaktion'");
	
EndFunction

Function GetTitleManual() Export
	
	Return NStr("en = 'Manual accounting transaction'; ru = 'Ручная бухгалтерская операция';pl = 'Ręczna transakcja księgowa';es_ES = 'Transacción contable manual';es_CO = 'Transacción contable manual';tr = 'Manuel muhasebe işlemi';it = 'Transazione contabile manuale';de = 'Manuelle Buchhaltungstransaktion'");
	
EndFunction

Function GetAcountingPolicyDate(DocumentObject) Export
	
	If ValueIsFilled(DocumentObject.BasisDocument) Then
		AccountingPolicyDate = Common.ObjectAttributeValue(DocumentObject.BasisDocument, "Date");
	Else
		AccountingPolicyDate = DocumentObject.Date;
	EndIf;
	
	Return AccountingPolicyDate;
	
EndFunction

#EndRegion

#Region Internal

#Region LibrariesHandlers

#Region PrintInterface

Procedure AddPrintCommands(PrintCommands) Export
	
EndProcedure

#EndRegion

#Region ObjectVersioning

Procedure OnDefineObjectVersioningSettings(Settings) Export

EndProcedure

#EndRegion

#EndRegion

#EndRegion

#EndIf