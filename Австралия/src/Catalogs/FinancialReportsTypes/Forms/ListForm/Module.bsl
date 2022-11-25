#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	ConditionalAppearanceItems = List.ConditionalAppearance.Items;
	
	Item = ConditionalAppearanceItems.Add();
	Item.Appearance.SetParameterValue("TextColor", WebColors.Magenta);
	StrikedOutFont = New Font( , , , , , True);
	Item.Appearance.SetParameterValue("Font", StrikedOutFont);
	FilterItem = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterItem.LeftValue = New DataCompositionField("DeletionMark");
	FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
	FilterItem.RightValue = True;
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject);
	
EndProcedure

#EndRegion