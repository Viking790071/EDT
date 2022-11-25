
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If ValueIsFilled(Object.Ref) Then
		
		SetObjectColors(Object.Ref);
		
	ElsIf Parameters.Property("CopyingValue") AND ValueIsFilled(Parameters.CopyingValue) Then
		
		SetObjectColors(Parameters.CopyingValue);
		
	EndIf;
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject, Object);
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	For Each Activity In Object.Activities Do
			
		CurrentObject.Activities[Activity.LineNumber-1].HighlightColor = New ValueStorage(Activity.Color);
			
	EndDo;
	
	NativeLanguagesSupportServer.BeforeWriteAtServer(CurrentObject);
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("Write_Campaigns");
	SetObjectColors(Object.Ref);
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ActivitiesOnChange(Item)
	
	SetConditionalAppearance();
	
EndProcedure

&AtClient
Procedure Attachable_Open(Item, StandardProcessing)
	NativeLanguagesSupportClient.OnOpen(ThisObject, Object, Item, StandardProcessing);
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()
	
	ConditionalAppearance.Items.Clear();
	
	For Each Activity In Object.Activities Do
		
		SetLineConditionalAppearance(Activity.LineNumber, Activity.Color);
		
	EndDo;
	
EndProcedure

&AtServer
Procedure SetLineConditionalAppearance(LineNumber, Color)
	
	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField("ActivitiesColor");

	FilterItem = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterItem.LeftValue		= New DataCompositionField("Object.Activities.LineNumber");
	FilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	FilterItem.RightValue		= LineNumber;

	Item.Appearance.SetParameterValue("BackColor", Color);
	
	Item.Use = True;
	
EndProcedure

&AtServer
Procedure SetObjectColors(CampaignRef)
	
	For Each Activity In CampaignRef.Activities Do
		
		Object.Activities[Activity.LineNumber-1].Color = Activity.HighlightColor.Get();
		
	EndDo;
	
	SetConditionalAppearance();
	
EndProcedure

#EndRegion

