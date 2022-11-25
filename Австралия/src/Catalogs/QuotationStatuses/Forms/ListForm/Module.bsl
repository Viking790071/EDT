
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SetConditionalAppearance();
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject);
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Write_QuotationStatuse" Then
		SetConditionalAppearance();
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()
	
	ConditionalAppearance.Items.Clear();
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	QuotationStatuses.Ref AS Ref,
		|	QuotationStatuses.HighlightColor AS HighlightColor
		|FROM
		|	Catalog.QuotationStatuses AS QuotationStatuses
		|WHERE
		|	NOT QuotationStatuses.DeletionMark";
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	EmptyColor = StyleColors.ToolTipTextColor;
	
	While SelectionDetailRecords.Next() Do
		
		Color = SelectionDetailRecords.HighlightColor.Get();
		
		If Color <> EmptyColor Then
			SetLineConditionalAppearance(SelectionDetailRecords.Ref, Color)
		EndIf;
		
	EndDo;
	
EndProcedure

&AtServer
Procedure SetLineConditionalAppearance(Ref, Color)
	
	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField("Description");

	FilterItem = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterItem.LeftValue		= New DataCompositionField("List.Ref");
	FilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	FilterItem.RightValue		= Ref;

	Item.Appearance.SetParameterValue("BackColor", Color);
	
	Item.Use = True;
	
EndProcedure

#EndRegion

