#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Internal

Procedure CreateNewHierarchy(RefBOM) Export
	
	If Not ValueIsFilled(RefBOM) Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	ParentHierarchy.Ref AS Ref,
	|	ParentHierarchy.Parent AS Parent,
	|	ParentHierarchy.Specification AS Specification
	|INTO ParentHierarchyTable
	|FROM
	|	Catalog.BillsOfMaterialsHierarchy AS ParentHierarchy
	|WHERE
	|	ParentHierarchy.Specification = &RefBOM
	|	AND NOT ParentHierarchy.DeletionMark
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ChildHierarchyTable.Ref AS Ref
	|FROM
	|	ParentHierarchyTable AS ParentHierarchyTable
	|		INNER JOIN Catalog.BillsOfMaterialsHierarchy AS ChildHierarchyTable
	|		ON ParentHierarchyTable.Ref = ChildHierarchyTable.Parent
	|WHERE
	|	NOT ChildHierarchyTable.DeletionMark
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	BillsOfMaterials.Ref AS Specification,
	|	BillsOfMaterials.Description AS Description
	|FROM
	|	Catalog.BillsOfMaterials AS BillsOfMaterials
	|		LEFT JOIN ParentHierarchyTable AS ParentHierarchy
	|		ON BillsOfMaterials.Ref = ParentHierarchy.Specification
	|			AND (ParentHierarchy.Parent = VALUE(Catalog.BillsOfMaterialsHierarchy.EmptyRef))
	|WHERE
	|	BillsOfMaterials.Ref = &RefBOM
	|	AND NOT BillsOfMaterials.DeletionMark
	|	AND ParentHierarchy.Ref IS NULL
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ParentHierarchy.Ref AS RefHierarchy,
	|	BillsOfMaterials.Ref AS Specification
	|FROM
	|	Catalog.BillsOfMaterials AS BillsOfMaterials
	|		INNER JOIN ParentHierarchyTable AS ParentHierarchy
	|		ON BillsOfMaterials.Ref = ParentHierarchy.Specification
	|WHERE
	|	NOT BillsOfMaterials.DeletionMark";
	
	Query.SetParameter("RefBOM", RefBOM);
	
	Result = Query.ExecuteBatch();
	
	Selection = Result[1].Select();
	While Selection.Next() Do
		Selection.Ref.GetObject().SetDeletionMark(True);
	EndDo;
	
	Selection = Result[2].Select();
	If Selection.Next() Then
		NewHierarchyItem = Catalogs.BillsOfMaterialsHierarchy.CreateItem();
		FillPropertyValues(NewHierarchyItem, Selection);
		NewHierarchyItem.Write();
		CreateChildHierarchy(Selection.Specification, NewHierarchyItem.Ref);
	EndIf;
	
	Selection = Result[3].Select();
	While Selection.Next() Do
		CreateChildHierarchy(Selection.Specification, Selection.RefHierarchy);
	EndDo;
	
EndProcedure

Procedure ClearBOMHierarchy(RefBOM) Export
	
	If Not ValueIsFilled(RefBOM) Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	BillsOfMaterialsHierarchy.Ref AS Ref
	|FROM
	|	Catalog.BillsOfMaterialsHierarchy AS BillsOfMaterialsHierarchy
	|WHERE
	|	BillsOfMaterialsHierarchy.Specification = &RefBOM
	|	AND NOT BillsOfMaterialsHierarchy.DeletionMark";
	
	Query.SetParameter("RefBOM", RefBOM);
	
	Result = Query.Execute();
	
	Selection = Result.Select();
	While Selection.Next() Do
		Selection.Ref.GetObject().SetDeletionMark(True);
	EndDo;
	
EndProcedure

#EndRegion

#Region Private

Procedure CreateChildHierarchy(ParentBOM, ParentHierarchy)
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	BillsOfMaterialsContent.Specification AS Specification,
	|	ChildBillsOfMaterials.Description AS Description
	|FROM
	|	Catalog.BillsOfMaterials.Content AS BillsOfMaterialsContent
	|		INNER JOIN Catalog.BillsOfMaterials AS ChildBillsOfMaterials
	|		ON BillsOfMaterialsContent.Specification = ChildBillsOfMaterials.Ref
	|WHERE
	|	BillsOfMaterialsContent.Ref = &ParentBOM
	|	AND NOT ChildBillsOfMaterials.DeletionMark";
	
	Query.SetParameter("ParentBOM", ParentBOM);
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		
		NewHierarchyItem = Catalogs.BillsOfMaterialsHierarchy.CreateItem();
		FillPropertyValues(NewHierarchyItem, Selection, "Description, Specification");
		NewHierarchyItem.Parent = ParentHierarchy;
		NewHierarchyItem.Write();
		
		CreateChildHierarchy(Selection.Specification, NewHierarchyItem.Ref);
		
	EndDo;
	
EndProcedure

#EndRegion

#EndIf