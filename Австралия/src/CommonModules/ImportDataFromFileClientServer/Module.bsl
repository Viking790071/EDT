#Region Public

// Creates a structure to describe columns for a template of importing data from file.
//
// Parameters:
//  Name - String - a column name.
//  Type - TypesDetails - a column type.
//  Header - String - a column header displayed in the template for import.
//  Width - Number - a column width.
//  Header - String - a tooltip displayed in the column header.
// 
// Returns:
//  Structure - a structure with column details.
//  * Name - String - a column name.
//  * Type - TypesDetails - a column type.
//  * Header - String - a column header displayed in the template for import.
//  * Width - Number - a column width.
//  * Header - String - a tooltip displayed in the column header.
//  * Required - Boolean - True if a column must contain values.
//  * Group - String - a column group name.
//  * Parent - String - used to connect the dynamic column with an attribute of the object tabular section.
//
Function TemplateColumnDetails(Name, Type, Header = Undefined, Width = 0, Tooltip = "") Export
	
	TemplateColumn = New Structure("Name, Type, Title, Width, Position, ToolTip, Required, Group, Parent");
	TemplateColumn.Name = Name;
	TemplateColumn.Type = Type;
	TemplateColumn.Title = ?(ValueIsFilled(Header), Header, Name);
	TemplateColumn.Width = ?(Width = 0, 30, Width);
	TemplateColumn.ToolTip = Tooltip;
	TemplateColumn.Parent = Name;
	
	Return TemplateColumn;
	
EndFunction

// Returns a template column by its name.
//
// Parameters:
//  Name				 - String - a column name.
//  ColumnList	 - Array - a set of template columns.
// 
// Returns:
//  Structure - a structure with column details. See structure components in the TemplateColumnDetails function.
//              If a column is missing, then Undefined.
//
Function TemplateColumn(Name, ColumnsList) Export
	For each Column In  ColumnsList Do
		If Column.Name = Name Then
			Return Column;
		EndIf;
	EndDo;
	
	Return Undefined;
EndFunction

// Deletes a template column from the array.
//
// Parameters:
//  Name				 - String - a column name.
//  ColumnList	 - Array - a set of template columns.
//
Procedure DeleteTemplateColumn(Name, ColumnsList) Export
	
	For Index = 0 To ColumnsList.Count() -1  Do
		If ColumnsList[Index].Name = Name Then
			ColumnsList.Delete(Index);
			Return;
		EndIf;
	EndDo;
	
EndProcedure

#EndRegion

#Region Private

Function ColumnsHaveGroup(Val ColumnsInformation) Export
	ColumnsGroups = New Map;
	For each TableColumn In ColumnsInformation Do
		ColumnsGroups.Insert(TableColumn.Group);
	EndDo;
	Return ?(ColumnsGroups.Count() > 1, True, False);
EndFunction

#EndRegion
