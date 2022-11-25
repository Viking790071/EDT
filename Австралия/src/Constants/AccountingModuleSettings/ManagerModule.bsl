#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

Function UseTemplatesIsEnabled() Export
	
	Return Constants.AccountingModuleSettings.Get() = Enums.AccountingModuleSettingsTypes.UseTemplateBasedTypesOfAccounting;
	
EndFunction

Function RegisterAccountingEntriesIsEnabled() Export
	
	Return Constants.AccountingModuleSettings.Get() <> Enums.AccountingModuleSettingsTypes.DoNotUseAccountingModule;
	
EndFunction

Procedure FillPredefinedDataProperties() Export
	Constants.AccountingModuleSettings.Set(Enums.AccountingModuleSettingsTypes.UseDefaultTypeOfAccounting);
	Constants.UseDefaultTypeOfAccounting.Set(True);
	
	Constants.UseAccountingTemplates.Set(False);
	
	If Constants.UseBudgeting.Get() Then
		Constants.UseGLAccountsBudgeting.Set(True);
	EndIf;
EndProcedure

#EndRegion

#Region Internal

#Region InfobaseUpdate

Procedure UpdatePredefinedAccountingSettings() Export
	
	If ValueIsFilled(Constants.AccountingModuleSettings.Get()) Then
		Return;
	EndIf;
	
	UseDefaultTypeOfAccounting = Constants.UseDefaultTypeOfAccounting.Get();
	
	If UseDefaultTypeOfAccounting Then
		FillPredefinedDataProperties();
	Else
		Constants.AccountingModuleSettings.Set(Enums.AccountingModuleSettingsTypes.DoNotUseAccountingModule);
		Constants.UseAccountingTemplates.Set(False);
	EndIf;
	
EndProcedure

#EndRegion

#EndRegion

#EndIf