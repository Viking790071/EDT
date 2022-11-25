#Region Public

Function GetEmptyValues() Export
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	MetadataObjectIDs.EmptyRefValue AS EmptyRefValue
	|FROM
	|	Catalog.MetadataObjectIDs AS MetadataObjectIDs
	|WHERE
	|	MetadataObjectIDs.EmptyRefValue <> UNDEFINED";
	
	QueryResult = Query.Execute();
	
	EmptyValues = QueryResult.Unload().UnloadColumn("EmptyRefValue");
	
	EmptyValues.Add(0);
	EmptyValues.Add("");
	EmptyValues.Add(Undefined);
	EmptyValues.Add(Date(1, 1, 1, 0, 0, 0));
	
	For Each MetadataItem In Metadata.Enums Do
		Enums[MetadataItem.Name].EmptyRef();
	EndDo;
	
	Return EmptyValues;
	
EndFunction

#EndRegion