#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Object.WorkCenterTypes.Count() Then
		WorkCenterType = Object.WorkCenterTypes[0].WorkcenterType;
	EndIf;
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject, Object);
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	Object.WorkCenterTypes.Clear();
	
	If ValueIsFilled(WorkCenterType) Then
		
		NewLine = Object.WorkCenterTypes.Add();
		NewLine.WorkcenterType = WorkCenterType;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)

	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)

	NativeLanguagesSupportServer.BeforeWriteAtServer(CurrentObject);
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)

	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure Attachable_Open(Item, StandardProcessing)
	NativeLanguagesSupportClient.OnOpen(ThisObject, Object, Item, StandardProcessing);
EndProcedure

&AtClient
Procedure StandardTimeInUOMOnChange(Item)
	
	CalculateStandardTime();
	
EndProcedure

&AtClient
Procedure TimeUOMOnChange(Item)
	
	CalculateStandardTime();
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure CalculateStandardTime()
	
	UOMFactor = TimeUOMFactor(Object.TimeUOM);
	Object.StandardTime = Object.StandardTimeInUOM * UOMFactor;
	
EndProcedure

&AtServerNoContext
Function TimeUOMFactor(TimeUOM);
	
	Result = 0;
	
	If ValueIsFilled(TimeUOM) Then
		Result = Common.ObjectAttributeValue(TimeUOM, "Factor");
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion