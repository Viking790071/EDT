#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

Function PeriodRepresentationParameter() Export 
	Return "[PeriodRepresentation]";
EndFunction

Procedure ReplaceParameterInContent(Content, ChargeFrequency, Date) Export
	
	If ChargeFrequency = Enums.Periodicity.Day Then
		ReplaceSubstring = Format(Date, "DLF=D");
	ElsIf ChargeFrequency = Enums.Periodicity.Month Then 
		ReplaceSubstring = Format(Date, "DF=MMMM") + " " + Format(Year(Date), "NG=");
	ElsIf ChargeFrequency = Enums.Periodicity.Year Then 
		ReplaceSubstring = NStr("en = 'the year'; ru = 'год';pl = 'rok';es_ES = 'el año';es_CO = 'el año';tr = 'yıl';it = 'l''anno';de = 'das Jahr'") + " " + Format(Year(Date), "NG=");
	Else
		Return;
	EndIf;
	
	SearchSubstring = PeriodRepresentationParameter();
	
	Content = StrReplace(Content, SearchSubstring, ReplaceSubstring);
	
EndProcedure

#Region ObjectAttributesLock

// StandardSubsystems.ObjectAttributesLock

// See ObjectsAttributesEditBlockedOverridable.OnDefineObjectsWithLockedAttributes. 
Function GetObjectAttributesToLock() Export
	
	AttributesToLock = New Array;
	AttributesToLock.Add("UserDefinedStartDate");
	AttributesToLock.Add("UserDefinedEndDate");
	AttributesToLock.Add("UserDefinedDateType");
	AttributesToLock.Add("UserDefinedBusinessCalendar");
	AttributesToLock.Add("UserDefinedDayOf");
	AttributesToLock.Add("UserDefinedCalculateFrom");
	
	AttributesToLock.Add("ChargeFrequency");
	AttributesToLock.Add("TypeOfDocument");
	AttributesToLock.Add("Enabled");
	AttributesToLock.Add("Template");
	AttributesToLock.Add("Company");
	AttributesToLock.Add("UseCustomSchedule");
	
	AttributesToLock.Add("Inventory");
	
	Return AttributesToLock;
	
EndFunction

// End StandardSubsystems.ObjectAttributesLock

#EndRegion

#EndRegion

#Region EventHandlers

Procedure ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing)
	
	NativeLanguagesSupportServer.ChoiceDataGetProcessing(
		ChoiceData,
		Parameters,
		StandardProcessing,
		Metadata.Catalogs.SubscriptionPlans);
	
EndProcedure

Procedure PresentationGetProcessing(Data, Presentation, StandardProcessing)
	
	NationalLanguageSupportClientServer.PresentationGetProcessing(Data, Presentation, StandardProcessing);
	
EndProcedure

Procedure PresentationFieldsGetProcessing(Fields, StandardProcessing)
	
	NationalLanguageSupportClientServer.PresentationFieldsGetProcessing(Fields, StandardProcessing);
	
EndProcedure

#EndRegion

#EndIf

