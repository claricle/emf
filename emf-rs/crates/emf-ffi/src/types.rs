use emf_core::Document;

pub const EMF_ABI_VERSION: u32 = 1;
pub const EMF_OK: i32 = 0;
pub const EMF_INVALID_ARGUMENT: i32 = 1;
pub const EMF_FORMAT_ERROR: i32 = 2;
pub const EMF_LIMIT_EXCEEDED: i32 = 3;
pub const EMF_SERIALIZE_ERROR: i32 = 4;
pub const EMF_INTERNAL_ERROR: i32 = 5;
pub const EMF_ALLOCATION_FAILED: i32 = 6;

#[repr(C)]
pub struct EmfDocument {
    pub(crate) document: Document,
}

#[repr(C)]
pub struct EmfBuffer {
    pub(crate) bytes: Vec<u8>,
}

#[repr(C)]
pub struct EmfError {
    pub(crate) status: i32,
    pub(crate) offset: Option<u64>,
    pub(crate) message: Vec<u8>,
}

#[repr(C)]
#[derive(Clone, Copy, Debug)]
pub struct EmfLimits {
    pub struct_size: u32,
    pub version: u32,
    pub max_input_bytes: u64,
    pub max_record_bytes: u64,
    pub max_records: u64,
    pub max_allocated_bytes: u64,
    pub max_work_units: u64,
}

#[repr(C)]
#[derive(Clone, Copy, Debug, Default)]
pub struct EmfInfo {
    pub struct_size: u32,
    pub version: u32,
    pub format: u32,
    pub has_eof: u32,
    pub header_bytes: u64,
    pub record_count: u64,
    pub diagnostic_count: u64,
    pub trailing_bytes: u64,
    pub unframed_bytes: u64,
    pub reserved: u64,
}

#[repr(C)]
#[derive(Clone, Copy, Debug, Default)]
pub struct EmfRecordDescriptor {
    pub struct_size: u32,
    pub version: u32,
    pub index: u64,
    pub offset: u64,
    pub byte_length: u64,
    pub type_id: u32,
    pub family: u32,
}

#[repr(C)]
#[derive(Clone, Copy, Debug)]
pub struct EmfErrorInfo {
    pub struct_size: u32,
    pub version: u32,
    pub status: i32,
    pub category: u32,
    pub has_offset: u32,
    pub reserved: u32,
    pub offset: u64,
    pub message: *const u8,
    pub message_length: u64,
}

/// Owned WMF handle, distinct from an EMF document handle.
#[repr(C)]
pub struct WmfDocument {
    pub(crate) document: emf_core::wmf::Document,
}
