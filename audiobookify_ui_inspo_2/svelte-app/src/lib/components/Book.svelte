<script lang="ts">
  import { T, useTask } from '@threlte/core';
  import { RoundedBoxGeometry, Text, interactivity } from '@threlte/extras';
  import * as THREE from 'three';
  import type { BookData } from './types';

  interactivity();

  interface Props {
    data: BookData;
    index: number;
    totalBooks: number;
    activeBookId: number | null;
    onSelect: (id: number) => void;
  }

  let { data, index, totalBooks, activeBookId, onSelect }: Props = $props();

  const SPINE_WIDTH_BASE = 0.15;
  const BOOK_HEIGHT = 1.2;
  const BOOK_DEPTH = 0.9;

  // Calculate thickness based on duration
  const thickness = $derived(SPINE_WIDTH_BASE + (data.duration / 100));

  const isActive = $derived(activeBookId === data.id);
  const isOtherActive = $derived(activeBookId !== null && !isActive);

  let hovered = $state(false);

  // Create refs for the mesh
  let groupRef: THREE.Group | undefined = $state();

  // Target vectors for animation
  const targetPos = new THREE.Vector3();
  const targetQuat = new THREE.Quaternion();

  useTask((delta) => {
    if (!groupRef) return;

    if (isActive) {
      // Float in front of camera
      const t = performance.now() / 1000;
      targetPos.set(0, 0.5 + Math.sin(t) * 0.05, 3.5);
      targetQuat.setFromEuler(new THREE.Euler(0, Math.PI, 0));
    } else if (isOtherActive) {
      // Fade into background
      const xPos = (index - totalBooks / 2) * 0.35;
      targetPos.set(xPos, -0.2, 0);
      targetQuat.setFromEuler(new THREE.Euler(0, 0, 0));
    } else {
      // Resting shelf position
      const xPos = (index - totalBooks / 2) * (SPINE_WIDTH_BASE + 0.25);
      targetPos.set(xPos, 0, 0);
      targetQuat.setFromEuler(new THREE.Euler(0, 0, 0));

      // Hover effect
      if (hovered) {
        targetPos.z = 0.3;
        targetPos.y = 0.1;
      }
    }

    // Smooth lerp
    groupRef.position.lerp(targetPos, 0.1);
    groupRef.quaternion.slerp(targetQuat, 0.1);
  });

  function handleClick(e: MouseEvent) {
    e.stopPropagation();
    if (!activeBookId) {
      onSelect(data.id);
    }
  }
</script>

<T.Group
  bind:ref={groupRef}
  onclick={handleClick}
  onpointerenter={() => (hovered = true)}
  onpointerleave={() => (hovered = false)}
>
  <!-- Book Cover/Spine Mesh -->
  <T.Mesh>
    <RoundedBoxGeometry args={[thickness, BOOK_HEIGHT, BOOK_DEPTH]} radius={0.05} />
    <T.MeshStandardMaterial color={data.color} roughness={0.4} metalness={0.1} />
  </T.Mesh>

  <!-- Pages (White block inside) -->
  <T.Mesh>
    <T.BoxGeometry args={[thickness - 0.02, BOOK_HEIGHT - 0.1, BOOK_DEPTH - 0.05]} />
    <T.MeshStandardMaterial color="#fdfbf7" />
  </T.Mesh>

  <!-- Spine Text -->
  <T.Group position={[0, 0, BOOK_DEPTH / 2 + 0.01]}>
    <Text
      text={data.title}
      position={[0, 0.2, 0]}
      rotation={[0, 0, -Math.PI / 2]}
      fontSize={0.12}
      maxWidth={BOOK_HEIGHT - 0.2}
      anchorX="center"
      anchorY="middle"
      color={data.textColor || '#ffffff'}
    />
    <Text
      text={data.author.toUpperCase()}
      position={[0, -0.4, 0]}
      rotation={[0, 0, -Math.PI / 2]}
      fontSize={0.06}
      anchorX="center"
      anchorY="middle"
      color={data.textColor || '#ffffff'}
    />
  </T.Group>
</T.Group>
