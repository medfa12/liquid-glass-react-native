// Headless Vulkan renderer for the Liquid Glass shader.
//
// The point of this over the D3D path: it consumes portable/generated/*.spv
// VERBATIM. No GLSL->SPIR-V->HLSL->fxc chain, so nothing can silently rewrite
// the maths between the canonical shader and what actually runs. On macOS this
// runs through MoltenVK, which means it can be diffed pixel-for-pixel against
// the real NSGlassEffectView captures taken earlier.
#include <vulkan/vulkan.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define VKC(x) do { VkResult _r = (x); if (_r != VK_SUCCESS) { \
  fprintf(stderr, "FAIL %s -> %d (line %d)\n", #x, _r, __LINE__); exit(1); } } while (0)

#define W 256
#define H 160
#define PARAM_FLOATS 168      /* 672 bytes, std140 block rounded to 16 */

static uint32_t *load_spv(const char *p, size_t *n) {
  FILE *f = fopen(p, "rb"); if (!f) { perror(p); exit(1); }
  fseek(f, 0, SEEK_END); *n = ftell(f); fseek(f, 0, SEEK_SET);
  uint32_t *b = malloc(*n); fread(b, 1, *n, f); fclose(f); return b;
}

static uint32_t mem_type(VkPhysicalDevice pd, uint32_t bits, VkMemoryPropertyFlags want) {
  VkPhysicalDeviceMemoryProperties mp; vkGetPhysicalDeviceMemoryProperties(pd, &mp);
  for (uint32_t i = 0; i < mp.memoryTypeCount; i++)
    if ((bits & (1u << i)) && (mp.memoryTypes[i].propertyFlags & want) == want) return i;
  fprintf(stderr, "no memory type\n"); exit(1);
}

int main(int argc, char **argv) {
  const char *frag_path = argc > 1 ? argv[1] : "liquid_glass.spv";

  VkApplicationInfo app = { .sType = VK_STRUCTURE_TYPE_APPLICATION_INFO,
                            .apiVersion = VK_API_VERSION_1_1 };
  const char *inst_ext[] = { "VK_KHR_portability_enumeration",
                             "VK_KHR_get_physical_device_properties2" };
  VkInstanceCreateInfo ici = { .sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
    .pApplicationInfo = &app, .enabledExtensionCount = 2,
    .ppEnabledExtensionNames = inst_ext,
    .flags = VK_INSTANCE_CREATE_ENUMERATE_PORTABILITY_BIT_KHR };
  VkInstance inst; VKC(vkCreateInstance(&ici, NULL, &inst));

  uint32_t nd = 0; vkEnumeratePhysicalDevices(inst, &nd, NULL);
  VkPhysicalDevice *pds = malloc(nd * sizeof *pds);
  vkEnumeratePhysicalDevices(inst, &nd, pds);
  VkPhysicalDevice pd = pds[0];
  VkPhysicalDeviceProperties props; vkGetPhysicalDeviceProperties(pd, &props);
  printf("device: %s (API %u.%u.%u)\n", props.deviceName,
         VK_VERSION_MAJOR(props.apiVersion), VK_VERSION_MINOR(props.apiVersion),
         VK_VERSION_PATCH(props.apiVersion));

  uint32_t nq = 0; vkGetPhysicalDeviceQueueFamilyProperties(pd, &nq, NULL);
  VkQueueFamilyProperties *qs = malloc(nq * sizeof *qs);
  vkGetPhysicalDeviceQueueFamilyProperties(pd, &nq, qs);
  uint32_t qf = 0; for (uint32_t i = 0; i < nq; i++)
    if (qs[i].queueFlags & VK_QUEUE_GRAPHICS_BIT) { qf = i; break; }

  float prio = 1.0f;
  VkDeviceQueueCreateInfo dq = { .sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
    .queueFamilyIndex = qf, .queueCount = 1, .pQueuePriorities = &prio };
  const char *dev_ext[] = { "VK_KHR_portability_subset" };
  VkDeviceCreateInfo dci = { .sType = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
    .queueCreateInfoCount = 1, .pQueueCreateInfos = &dq,
    .enabledExtensionCount = 1, .ppEnabledExtensionNames = dev_ext };
  VkDevice dev; VKC(vkCreateDevice(pd, &dci, NULL, &dev));
  VkQueue q; vkGetDeviceQueue(dev, qf, 0, &q);

  /* ---- colour target ---- */
  VkImageCreateInfo ii = { .sType = VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO,
    .imageType = VK_IMAGE_TYPE_2D, .format = VK_FORMAT_R8G8B8A8_UNORM,
    .extent = { W, H, 1 }, .mipLevels = 1, .arrayLayers = 1,
    .samples = VK_SAMPLE_COUNT_1_BIT, .tiling = VK_IMAGE_TILING_OPTIMAL,
    .usage = VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT | VK_IMAGE_USAGE_TRANSFER_SRC_BIT,
    .initialLayout = VK_IMAGE_LAYOUT_UNDEFINED };
  VkImage img; VKC(vkCreateImage(dev, &ii, NULL, &img));
  VkMemoryRequirements mr; vkGetImageMemoryRequirements(dev, img, &mr);
  VkMemoryAllocateInfo ma = { .sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
    .allocationSize = mr.size,
    .memoryTypeIndex = mem_type(pd, mr.memoryTypeBits, VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT) };
  VkDeviceMemory imem; VKC(vkAllocateMemory(dev, &ma, NULL, &imem));
  VKC(vkBindImageMemory(dev, img, imem, 0));
  VkImageViewCreateInfo ivi = { .sType = VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
    .image = img, .viewType = VK_IMAGE_VIEW_TYPE_2D, .format = VK_FORMAT_R8G8B8A8_UNORM,
    .subresourceRange = { VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1 } };
  VkImageView iv; VKC(vkCreateImageView(dev, &ivi, NULL, &iv));

  /* ---- backdrop: hard dark|bright edge, with a mip chain for the blur ---- */
  const uint32_t BW = 128, BH = 128;
  uint32_t MIPS = 1; { uint32_t s = BW > BH ? BW : BH; while (s > 1) { s >>= 1; MIPS++; } }
  VkImageCreateInfo bi = ii;
  bi.extent = (VkExtent3D){ BW, BH, 1 }; bi.mipLevels = MIPS;
  bi.usage = VK_IMAGE_USAGE_SAMPLED_BIT | VK_IMAGE_USAGE_TRANSFER_DST_BIT |
             VK_IMAGE_USAGE_TRANSFER_SRC_BIT;
  VkImage bimg; VKC(vkCreateImage(dev, &bi, NULL, &bimg));
  vkGetImageMemoryRequirements(dev, bimg, &mr);
  ma.allocationSize = mr.size;
  ma.memoryTypeIndex = mem_type(pd, mr.memoryTypeBits, VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT);
  VkDeviceMemory bmem; VKC(vkAllocateMemory(dev, &ma, NULL, &bmem));
  VKC(vkBindImageMemory(dev, bimg, bmem, 0));
  VkImageViewCreateInfo bivi = ivi;
  bivi.image = bimg; bivi.subresourceRange.levelCount = MIPS;
  VkImageView biv; VKC(vkCreateImageView(dev, &bivi, NULL, &biv));

  /* staging for backdrop upload + result readback */
  VkBufferCreateInfo bci = { .sType = VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
    .size = (VkDeviceSize)W * H * 4, .usage = VK_BUFFER_USAGE_TRANSFER_SRC_BIT |
    VK_BUFFER_USAGE_TRANSFER_DST_BIT };
  VkBuffer stage; VKC(vkCreateBuffer(dev, &bci, NULL, &stage));
  vkGetBufferMemoryRequirements(dev, stage, &mr);
  ma.allocationSize = mr.size;
  ma.memoryTypeIndex = mem_type(pd, mr.memoryTypeBits,
      VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT);
  VkDeviceMemory smem; VKC(vkAllocateMemory(dev, &ma, NULL, &smem));
  VKC(vkBindBufferMemory(dev, stage, smem, 0));
  { void *p; VKC(vkMapMemory(dev, smem, 0, VK_WHOLE_SIZE, 0, &p));
    uint32_t *px = p;
    for (uint32_t y = 0; y < BH; y++) for (uint32_t x = 0; x < BW; x++)
      px[y*BW+x] = (x < BW/2) ? 0xFF202020u : 0xFFE0E0E0u;
    vkUnmapMemory(dev, smem); }

  /* ---- uniform buffer: 672-byte std140 block ---- */
  VkBufferCreateInfo uci = { .sType = VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
    .size = PARAM_FLOATS * 4, .usage = VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT };
  VkBuffer ubo; VKC(vkCreateBuffer(dev, &uci, NULL, &ubo));
  vkGetBufferMemoryRequirements(dev, ubo, &mr);
  ma.allocationSize = mr.size;
  ma.memoryTypeIndex = mem_type(pd, mr.memoryTypeBits,
      VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT);
  VkDeviceMemory umem; VKC(vkAllocateMemory(dev, &ma, NULL, &umem));
  VKC(vkBindBufferMemory(dev, ubo, umem, 0));
  float *P; VKC(vkMapMemory(dev, umem, 0, VK_WHOLE_SIZE, 0, (void**)&P));
  memset(P, 0, PARAM_FLOATS * 4);
  /* offsets from portable/liquid_glass_params.h (SPIR-V reflection) */
  #include "params_init.h"
  vkUnmapMemory(dev, umem);

  /* ---- shaders: our .spv, unmodified ---- */
  size_t fn, vn;
  uint32_t *fc = load_spv(frag_path, &fn);
  uint32_t *vc = load_spv("fullscreen.vert.spv", &vn);
  VkShaderModuleCreateInfo smf = { .sType = VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
    .codeSize = fn, .pCode = fc };
  VkShaderModule fs; VKC(vkCreateShaderModule(dev, &smf, NULL, &fs));
  smf.codeSize = vn; smf.pCode = vc;
  VkShaderModule vs; VKC(vkCreateShaderModule(dev, &smf, NULL, &vs));
  printf("SPIR-V loaded verbatim: frag %zu bytes, vert %zu bytes\n", fn, vn);

  /* ---- descriptors ---- */
  VkSampler samp; {
    VkSamplerCreateInfo si = { .sType = VK_STRUCTURE_TYPE_SAMPLER_CREATE_INFO,
      .magFilter = VK_FILTER_LINEAR, .minFilter = VK_FILTER_LINEAR,
      .mipmapMode = VK_SAMPLER_MIPMAP_MODE_LINEAR,
      .addressModeU = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE,
      .addressModeV = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE,
      .addressModeW = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE,
      .maxLod = (float)MIPS };
    VKC(vkCreateSampler(dev, &si, NULL, &samp)); }
  VkDescriptorSetLayoutBinding lb[2] = {
    { .binding = 0, .descriptorType = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
      .descriptorCount = 1, .stageFlags = VK_SHADER_STAGE_FRAGMENT_BIT },
    { .binding = 1, .descriptorType = VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
      .descriptorCount = 1, .stageFlags = VK_SHADER_STAGE_FRAGMENT_BIT } };
  VkDescriptorSetLayoutCreateInfo dl = {
    .sType = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
    .bindingCount = 2, .pBindings = lb };
  VkDescriptorSetLayout dsl; VKC(vkCreateDescriptorSetLayout(dev, &dl, NULL, &dsl));
  VkDescriptorPoolSize ps[2] = {
    { VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER, 1 },
    { VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER, 1 } };
  VkDescriptorPoolCreateInfo dp = { .sType = VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO,
    .maxSets = 1, .poolSizeCount = 2, .pPoolSizes = ps };
  VkDescriptorPool pool; VKC(vkCreateDescriptorPool(dev, &dp, NULL, &pool));
  VkDescriptorSetAllocateInfo dsa = { .sType = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO,
    .descriptorPool = pool, .descriptorSetCount = 1, .pSetLayouts = &dsl };
  VkDescriptorSet ds; VKC(vkAllocateDescriptorSets(dev, &dsa, &ds));

  /* ---- render pass + pipeline ---- */
  VkAttachmentDescription at = { .format = VK_FORMAT_R8G8B8A8_UNORM,
    .samples = VK_SAMPLE_COUNT_1_BIT, .loadOp = VK_ATTACHMENT_LOAD_OP_CLEAR,
    .storeOp = VK_ATTACHMENT_STORE_OP_STORE,
    .stencilLoadOp = VK_ATTACHMENT_LOAD_OP_DONT_CARE,
    .stencilStoreOp = VK_ATTACHMENT_STORE_OP_DONT_CARE,
    .initialLayout = VK_IMAGE_LAYOUT_UNDEFINED,
    .finalLayout = VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL };
  VkAttachmentReference ar = { 0, VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL };
  VkSubpassDescription sp = { .pipelineBindPoint = VK_PIPELINE_BIND_POINT_GRAPHICS,
    .colorAttachmentCount = 1, .pColorAttachments = &ar };
  VkRenderPassCreateInfo rp = { .sType = VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO,
    .attachmentCount = 1, .pAttachments = &at, .subpassCount = 1, .pSubpasses = &sp };
  VkRenderPass pass; VKC(vkCreateRenderPass(dev, &rp, NULL, &pass));
  VkFramebufferCreateInfo fb = { .sType = VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO,
    .renderPass = pass, .attachmentCount = 1, .pAttachments = &iv,
    .width = W, .height = H, .layers = 1 };
  VkFramebuffer fbo; VKC(vkCreateFramebuffer(dev, &fb, NULL, &fbo));

  VkPipelineLayoutCreateInfo pl = { .sType = VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
    .setLayoutCount = 1, .pSetLayouts = &dsl };
  VkPipelineLayout play; VKC(vkCreatePipelineLayout(dev, &pl, NULL, &play));
  VkPipelineShaderStageCreateInfo st[2] = {
    { .sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
      .stage = VK_SHADER_STAGE_VERTEX_BIT, .module = vs, .pName = "main" },
    { .sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
      .stage = VK_SHADER_STAGE_FRAGMENT_BIT, .module = fs, .pName = "main" } };
  VkPipelineVertexInputStateCreateInfo vi = {
    .sType = VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO };
  VkPipelineInputAssemblyStateCreateInfo ia = {
    .sType = VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
    .topology = VK_PRIMITIVE_TOPOLOGY_TRIANGLE_STRIP };
  VkViewport vp = { 0, 0, W, H, 0, 1 }; VkRect2D sc = { {0,0}, {W,H} };
  VkPipelineViewportStateCreateInfo vps = {
    .sType = VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO,
    .viewportCount = 1, .pViewports = &vp, .scissorCount = 1, .pScissors = &sc };
  VkPipelineRasterizationStateCreateInfo rs = {
    .sType = VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
    .polygonMode = VK_POLYGON_MODE_FILL, .cullMode = VK_CULL_MODE_NONE, .lineWidth = 1 };
  VkPipelineMultisampleStateCreateInfo ms = {
    .sType = VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
    .rasterizationSamples = VK_SAMPLE_COUNT_1_BIT };
  VkPipelineColorBlendAttachmentState cba = { .colorWriteMask = 0xF };
  VkPipelineColorBlendStateCreateInfo cb = {
    .sType = VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
    .attachmentCount = 1, .pAttachments = &cba };
  VkGraphicsPipelineCreateInfo gp = {
    .sType = VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO,
    .stageCount = 2, .pStages = st, .pVertexInputState = &vi,
    .pInputAssemblyState = &ia, .pViewportState = &vps,
    .pRasterizationState = &rs, .pMultisampleState = &ms,
    .pColorBlendState = &cb, .layout = play, .renderPass = pass };
  VkPipeline pipe; VKC(vkCreateGraphicsPipelines(dev, VK_NULL_HANDLE, 1, &gp, NULL, &pipe));
  printf("pipeline created (SPIR-V accepted by the driver)\n");

  /* ---- record ---- */
  VkCommandPoolCreateInfo cp = { .sType = VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
    .queueFamilyIndex = qf };
  VkCommandPool cpool; VKC(vkCreateCommandPool(dev, &cp, NULL, &cpool));
  VkCommandBufferAllocateInfo cba2 = { .sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
    .commandPool = cpool, .level = VK_COMMAND_BUFFER_LEVEL_PRIMARY, .commandBufferCount = 1 };
  VkCommandBuffer cmd; VKC(vkAllocateCommandBuffers(dev, &cba2, &cmd));
  VkCommandBufferBeginInfo cbi = { .sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
    .flags = VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT };
  VKC(vkBeginCommandBuffer(cmd, &cbi));

  VkImageMemoryBarrier bar = { .sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER,
    .oldLayout = VK_IMAGE_LAYOUT_UNDEFINED, .newLayout = VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
    .image = bimg, .subresourceRange = { VK_IMAGE_ASPECT_COLOR_BIT, 0, MIPS, 0, 1 },
    .dstAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT };
  vkCmdPipelineBarrier(cmd, VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT,
    VK_PIPELINE_STAGE_TRANSFER_BIT, 0, 0, NULL, 0, NULL, 1, &bar);
  VkBufferImageCopy bic = { .imageSubresource = { VK_IMAGE_ASPECT_COLOR_BIT, 0, 0, 1 },
    .imageExtent = { BW, BH, 1 } };
  vkCmdCopyBufferToImage(cmd, stage, bimg, VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, 1, &bic);

  /* build the mip chain the blur samples */
  int32_t mw = BW, mh = BH;
  for (uint32_t m = 1; m < MIPS; m++) {
    VkImageMemoryBarrier b2 = bar;
    b2.subresourceRange = (VkImageSubresourceRange){ VK_IMAGE_ASPECT_COLOR_BIT, m-1, 1, 0, 1 };
    b2.oldLayout = VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL;
    b2.newLayout = VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL;
    b2.srcAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT;
    b2.dstAccessMask = VK_ACCESS_TRANSFER_READ_BIT;
    vkCmdPipelineBarrier(cmd, VK_PIPELINE_STAGE_TRANSFER_BIT, VK_PIPELINE_STAGE_TRANSFER_BIT,
                         0, 0, NULL, 0, NULL, 1, &b2);
    VkImageBlit bl = {
      .srcSubresource = { VK_IMAGE_ASPECT_COLOR_BIT, m-1, 0, 1 },
      .srcOffsets = { {0,0,0}, { mw, mh, 1 } },
      .dstSubresource = { VK_IMAGE_ASPECT_COLOR_BIT, m, 0, 1 },
      .dstOffsets = { {0,0,0}, { mw>1?mw/2:1, mh>1?mh/2:1, 1 } } };
    vkCmdBlitImage(cmd, bimg, VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
                   bimg, VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, 1, &bl, VK_FILTER_LINEAR);
    if (mw > 1) mw /= 2; if (mh > 1) mh /= 2;
  }
  VkImageMemoryBarrier b3 = bar;
  b3.subresourceRange = (VkImageSubresourceRange){ VK_IMAGE_ASPECT_COLOR_BIT, 0, MIPS, 0, 1 };
  b3.oldLayout = VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL;
  b3.newLayout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;
  b3.srcAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT;
  b3.dstAccessMask = VK_ACCESS_SHADER_READ_BIT;
  vkCmdPipelineBarrier(cmd, VK_PIPELINE_STAGE_TRANSFER_BIT,
    VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT, 0, 0, NULL, 0, NULL, 1, &b3);

  VkDescriptorImageInfo dii = { samp, biv, VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL };
  VkDescriptorBufferInfo dbi = { ubo, 0, VK_WHOLE_SIZE };
  VkWriteDescriptorSet wr[2] = {
    { .sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET, .dstSet = ds, .dstBinding = 0,
      .descriptorCount = 1, .descriptorType = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
      .pImageInfo = &dii },
    { .sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET, .dstSet = ds, .dstBinding = 1,
      .descriptorCount = 1, .descriptorType = VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
      .pBufferInfo = &dbi } };
  vkUpdateDescriptorSets(dev, 2, wr, 0, NULL);

  VkClearValue clr = { .color = { .float32 = {0,0,0,0} } };
  VkRenderPassBeginInfo rbi = { .sType = VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO,
    .renderPass = pass, .framebuffer = fbo, .renderArea = sc,
    .clearValueCount = 1, .pClearValues = &clr };
  vkCmdBeginRenderPass(cmd, &rbi, VK_SUBPASS_CONTENTS_INLINE);
  vkCmdBindPipeline(cmd, VK_PIPELINE_BIND_POINT_GRAPHICS, pipe);
  vkCmdBindDescriptorSets(cmd, VK_PIPELINE_BIND_POINT_GRAPHICS, play, 0, 1, &ds, 0, NULL);
  vkCmdDraw(cmd, 4, 1, 0, 0);
  vkCmdEndRenderPass(cmd);

  VkBufferImageCopy rb = { .imageSubresource = { VK_IMAGE_ASPECT_COLOR_BIT, 0, 0, 1 },
    .imageExtent = { W, H, 1 } };
  vkCmdCopyImageToBuffer(cmd, img, VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL, stage, 1, &rb);
  VKC(vkEndCommandBuffer(cmd));

  VkSubmitInfo si2 = { .sType = VK_STRUCTURE_TYPE_SUBMIT_INFO,
    .commandBufferCount = 1, .pCommandBuffers = &cmd };
  VKC(vkQueueSubmit(q, 1, &si2, VK_NULL_HANDLE));
  VKC(vkQueueWaitIdle(q));

  /* ---- report ---- */
  uint8_t *out; VKC(vkMapMemory(dev, smem, 0, VK_WHOLE_SIZE, 0, (void**)&out));
  long covered = 0, lum = 0;
  for (int i = 0; i < W*H; i++) {
    uint8_t r = out[i*4], g = out[i*4+1], b = out[i*4+2], a = out[i*4+3];
    if (a > 8) { covered++; lum += (long)(0.2126*r + 0.7152*g + 0.0722*b); }
  }
  int cxi = ((H/2)*W + W/2) * 4;
  printf("centre RGBA = %d,%d,%d,%d\n", out[cxi], out[cxi+1], out[cxi+2], out[cxi+3]);
  printf("covered pixels: %ld / %d\n", covered, W*H);
  printf("mean luma inside: %ld\n", covered ? lum/covered : 0);
  printf("mid-row luma:");
  for (int x = 0; x < W; x += 16) {
    int i = ((H/2)*W + x)*4;
    printf(" %d", out[i+3] > 8 ? (int)(0.2126*out[i]+0.7152*out[i+1]+0.0722*out[i+2]) : -1);
  }
  printf("\nRESULT=%s\n", covered > 1000 ? "PASS glass rendered" : "FAIL nothing drawn");
  FILE *f = fopen("out.raw","wb"); fwrite(out, 1, (size_t)W*H*4, f); fclose(f);
  vkUnmapMemory(dev, smem);
  return covered > 1000 ? 0 : 2;
}
