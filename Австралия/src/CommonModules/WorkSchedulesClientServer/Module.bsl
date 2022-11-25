#Region Private

// The procedure shifts the edited collection row so that collection rows remain ordered.
// 
//
// Parameters:
//	RowCollection - row array, form data collection, value table.
//	OrderField - name of collection item field by which rows are ordered.
//		
//	CurrentRow - the edited collection row.
//
Procedure RestoreCollectionRowOrderAfterEditing(RowsCollection, OrderField, CurrentRow) Export
	
	If RowsCollection.Count() < 2 Then
		Return;
	EndIf;
	
	If TypeOf(CurrentRow[OrderField]) <> Type("Date") 
		AND Not ValueIsFilled(CurrentRow[OrderField]) Then
		Return;
	EndIf;
	
	SourceIndex = RowsCollection.IndexOf(CurrentRow);
	IndexResult = SourceIndex;
	
	// Select the direction in which to shift.
	Direction = 0;
	If SourceIndex = 0 Then
		// down
		Direction = 1;
	EndIf;
	If SourceIndex = RowsCollection.Count() - 1 Then
		// up
		Direction = -1;
	EndIf;
	
	If Direction = 0 Then
		If RowsCollection[SourceIndex][OrderField] > RowsCollection[IndexResult + 1][OrderField] Then
			// down
			Direction = 1;
		EndIf;
		If RowsCollection[SourceIndex][OrderField] < RowsCollection[IndexResult - 1][OrderField] Then
			// up
			Direction = -1;
		EndIf;
	EndIf;
	
	If Direction = 0 Then
		Return;
	EndIf;
	
	If Direction = 1 Then
		// Shift till the value in the current row is greater than in the following one.
		While IndexResult < RowsCollection.Count() - 1 
			AND RowsCollection[SourceIndex][OrderField] > RowsCollection[IndexResult + 1][OrderField] Do
			IndexResult = IndexResult + 1;
		EndDo;
	Else
		// Shift till the value in the current row is less than in the previous one.
		While IndexResult > 0 
			AND RowsCollection[SourceIndex][OrderField] < RowsCollection[IndexResult - 1][OrderField] Do
			IndexResult = IndexResult - 1;
		EndDo;
	EndIf;
	
	RowsCollection.Move(SourceIndex, IndexResult - SourceIndex);
	
EndProcedure

// Regenerates a fixed map by inserting the specified value into it.
//
Procedure InsertIntoFixedMap(FixedMap, varKey, Value) Export
	
	Map = New Map(FixedMap);
	Map.Insert(varKey, Value);
	FixedMap = New FixedMap(Map);
	
EndProcedure

// Removes value from the fixed map by the specified key.
//
Procedure DeleteFromFixedMap(FixedMap, varKey) Export
	
	Map = New Map(FixedMap);
	Map.Delete(varKey);
	FixedMap = New FixedMap(Map);
	
EndProcedure

#EndRegion
