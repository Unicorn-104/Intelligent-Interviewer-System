package com.ruoyi.enterprise.service;

import java.util.List;
import java.util.Set;
import com.ruoyi.enterprise.service.EnterpriseStorageReconciler.ObjectInventory;
import com.ruoyi.enterprise.service.EnterpriseStorageReconciler.OrphanHandler;
import com.ruoyi.enterprise.service.EnterpriseStorageReconciler.ReconcileReport;
import com.ruoyi.enterprise.service.EnterpriseStorageReconciler.ReferencedObjects;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class EnterpriseStorageReconcilerTest
{
    private ObjectInventory inventory;
    private ReferencedObjects referenced;
    private OrphanHandler handler;
    private EnterpriseStorageReconciler reconciler;

    @BeforeEach
    void setUp()
    {
        inventory = mock(ObjectInventory.class);
        referenced = mock(ReferencedObjects.class);
        handler = mock(OrphanHandler.class);
        reconciler = new EnterpriseStorageReconciler(inventory, referenced, handler);
    }

    @Test
    void deletesOnlyUnreferencedEnterpriseObjects()
    {
        String orphan = "enterprise-application-resume/9/100/a.pdf";
        String used = "enterprise-application-resume/9/101/b.pdf";
        when(inventory.listAllReferences()).thenReturn(List.of(orphan, used));
        when(referenced.referencedRefs()).thenReturn(Set.of(used));

        ReconcileReport report = reconciler.reconcile();
        assertEquals(2, report.scanned());
        assertEquals(List.of(orphan), report.deletedOrphans());
        assertTrue(report.retained().contains(used));
        verify(handler).delete(orphan);
        verify(handler, never()).delete(used);
    }

    @Test
    void neverTouchesNonEnterpriseNamespace()
    {
        String other = "private-resume/7/2026/01/01/c.pdf";
        when(inventory.listAllReferences()).thenReturn(List.of(other));
        when(referenced.referencedRefs()).thenReturn(Set.of());

        ReconcileReport report = reconciler.reconcile();
        assertTrue(report.retained().contains(other));
        verify(handler, never()).delete(any());
    }

    @Test
    void recognizesS3EnterpriseReference()
    {
        String s3Orphan = "s3:mybucket/enterprise-application-resume/9/102/d.pdf";
        when(inventory.listAllReferences()).thenReturn(List.of(s3Orphan));
        when(referenced.referencedRefs()).thenReturn(Set.of());

        ReconcileReport report = reconciler.reconcile();
        assertEquals(List.of(s3Orphan), report.deletedOrphans());
        verify(handler).delete(s3Orphan);
    }

    @Test
    void deleteFailureIsRecordedForRetryAndNoThrow()
    {
        String orphan = "enterprise-application-resume/9/103/e.pdf";
        doThrow(new RuntimeException("storage busy")).when(handler).delete(orphan);
        when(inventory.listAllReferences()).thenReturn(List.of(orphan));
        when(referenced.referencedRefs()).thenReturn(Set.of());

        ReconcileReport report = reconciler.reconcile();
        assertEquals(List.of(orphan), report.deleteFailed());
        assertTrue(report.deletedOrphans().isEmpty());
    }

    @Test
    void emptyInventoryProducesEmptyReport()
    {
        when(inventory.listAllReferences()).thenReturn(List.of());
        when(referenced.referencedRefs()).thenReturn(Set.of());
        ReconcileReport report = reconciler.reconcile();
        assertEquals(0, report.scanned());
        verify(handler, never()).delete(any());
    }
}
